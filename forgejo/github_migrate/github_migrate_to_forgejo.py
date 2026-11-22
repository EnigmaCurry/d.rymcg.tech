import os
import time
import sys
import requests
import argparse

FORGEJO_URL = os.environ.get("FORGEJO_URL")
FORGEJO_TOKEN = os.environ.get("FORGEJO_TOKEN")
GITHUB_USERNAME = os.environ.get("GITHUB_USERNAME")
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
FORGEJO_USERNAME = os.environ.get("FORGEJO_USERNAME")
MIRROR_INTERVAL = os.environ.get("MIRROR_INTERVAL", "8h0m0s")

assert (
    FORGEJO_URL
    and FORGEJO_TOKEN
    and GITHUB_USERNAME
    and GITHUB_TOKEN
    and FORGEJO_USERNAME
), "Missing required environment variables: FORGEJO_URL, FORGEJO_TOKEN, GITHUB_USERNAME, GITHUB_TOKEN, FORGEJO_USERNAME"

forgejo_session = requests.Session()
forgejo_session.headers.update(
    {
        "Authorization": f"token {FORGEJO_TOKEN}",
        "Content-Type": "application/json",
    }
)

github_session = requests.Session()
github_session.headers.update(
    {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github+json",
    }
)


def retry_request(session, method, url, **kwargs):
    for attempt in range(5):
        try:
            resp = session.request(method, url, **kwargs)
            if (
                resp.status_code == 403
                and "X-RateLimit-Remaining" in resp.headers
                and resp.headers["X-RateLimit-Remaining"] == "0"
            ):
                reset_time = int(
                    resp.headers.get("X-RateLimit-Reset", time.time() + 60)
                )
                wait = reset_time - int(time.time()) + 5
                print(f"[RATE LIMIT] Waiting {wait} seconds until reset...")
                time.sleep(wait)
                continue
            if resp.status_code >= 500:
                print(f"[RETRY] Server error {resp.status_code}, retrying...")
                time.sleep(2**attempt)
                continue
            return resp
        except requests.RequestException as e:
            print(f"[RETRY] Exception {e}, retrying...")
            time.sleep(2**attempt)
    raise Exception(f"Failed request after retries: {method} {url}")


def get_all_github_repos():
    repos = []
    url = f"https://api.github.com/user/repos?per_page=100&type=all&sort=full_name&direction=asc"
    while url:
        resp = retry_request(github_session, "GET", url)
        resp.raise_for_status()
        repos.extend(resp.json())
        links = resp.headers.get("Link", "")
        next_link = None
        for part in links.split(","):
            if 'rel="next"' in part:
                next_link = part[part.find("<") + 1 : part.find(">")]
                break
        url = next_link
    return repos


def forgejo_repo_status(owner, repo_name):
    url = f"{FORGEJO_URL}/api/v1/repos/{owner}/{repo_name}"
    resp = retry_request(forgejo_session, "GET", url)
    if resp.status_code == 404:
        return "missing"
    if resp.status_code != 200:
        raise Exception(
            f"Unexpected error checking repo {repo_name}: {resp.status_code} {resp.text}"
        )
    data = resp.json()

    if data.get("mirror") and data.get("original_url"):
        return "healthy"
    else:
        return "broken"


def delete_forgejo_repo(owner, repo_name):
    url = f"{FORGEJO_URL}/api/v1/repos/{owner}/{repo_name}"
    resp = retry_request(forgejo_session, "DELETE", url)
    if not resp.ok:
        raise Exception(
            f"Failed to delete repo {repo_name}: {resp.status_code} {resp.text}"
        )
    print(f"[DELETE] Deleted broken repo {repo_name}.")


def migrate_repo(owner, repo, delete_flag):
    name = repo["name"]
    private = repo["private"]
    description = repo.get("description") or ""
    source_url = repo["clone_url"].replace(
        "https://github.com/", f"https://{GITHUB_USERNAME}:{GITHUB_TOKEN}@github.com/"
    )
    topics = repo.get("topics", [])

    status = forgejo_repo_status(owner, name)

    if status == "healthy":
        print(f"[SKIP] {name} already exists and is a valid mirror.")
        return
    elif status == "broken":
        if delete_flag:
            print(f"[FIX] {name} exists but is broken. Deleting and recreating...")
            delete_forgejo_repo(owner, name)
            time.sleep(2)
        else:
            print(f"[WARN] {name} is broken, skipping. Use --delete to fix it.")
            return

    migrate_payload = {
        "clone_addr": source_url,
        "uid": 0,
        "repo_name": name,
        "private": private,
        "description": description,
        "mirror": True,
        "mirror_interval": MIRROR_INTERVAL,
    }

    print(f"[MIRROR] Creating mirror for {name}")
    resp = retry_request(
        forgejo_session,
        "POST",
        f"{FORGEJO_URL}/api/v1/repos/migrate",
        json=migrate_payload,
    )
    if not resp.ok:
        print(
            f"[ERROR] Failed to create mirror for {name}: {resp.status_code} {resp.text}"
        )
    else:
        if topics:
            retry_request(
                forgejo_session,
                "PUT",
                f"{FORGEJO_URL}/api/v1/repos/{owner}/{name}/topics",
                json=topics,
            )


def main(yes_flag, delete_flag):
    github_repos = get_all_github_repos()
    print(f"[INFO] Found {len(github_repos)} repositories on GitHub.")

    to_mirror = github_repos

    print("\n[DRY-RUN] Repositories to mirror:")
    for repo in to_mirror:
        print(f" - {repo['name']}")

    if not yes_flag:
        print("\n[INFO] Dry-run complete. Re-run with --yes to perform migration.")
        sys.exit(0)

    print("\n[EXECUTING] Creating mirrors...")
    for repo in to_mirror:
        migrate_repo(FORGEJO_USERNAME, repo, delete_flag)

    print("\n[DONE] All eligible repositories processed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Mirror GitHub repositories into Forgejo."
    )
    parser.add_argument(
        "--yes", action="store_true", help="Actually perform the migration."
    )
    parser.add_argument(
        "--delete", action="store_true", help="Allow deleting broken repositories."
    )
    args = parser.parse_args()
    main(args.yes, args.delete)
