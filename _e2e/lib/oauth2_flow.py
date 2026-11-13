"""oauth2_flow.py - drive the OAuth2 login flow like a browser would.

App (whoami behind oauth2-proxy) -> oauth2-proxy /oauth2/start -> Forgejo
login -> Forgejo grant page -> oauth2-proxy /oauth2/callback -> back to the
app. Prints one line per check:

    CHECK <name> <PASS|FAIL> <detail>

Passwords come from the environment (E2E_MEMBER_PASSWORD, E2E_OUTSIDER_PASSWORD)
so they never appear in a process listing. Run with:

    uv run --no-project --with requests python3 -I oauth2_flow.py --help
"""

import argparse
import os
import socket
import sys
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse

import requests


class FormParser(HTMLParser):
    """Collect every <form> with its action, method and input/button values."""

    def __init__(self):
        super().__init__()
        self.forms = []
        self._form = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "form":
            self._form = {
                "action": attrs.get("action", ""),
                "method": attrs.get("method", "get").lower(),
                "fields": {},
                "buttons": [],
            }
            self.forms.append(self._form)
        elif self._form is not None and tag == "input" and attrs.get("name"):
            if attrs.get("type") in ("checkbox", "radio") and "checked" not in attrs:
                return
            self._form["fields"][attrs["name"]] = attrs.get("value", "")
        elif self._form is not None and tag == "button" and attrs.get("name"):
            self._form["buttons"].append((attrs["name"], attrs.get("value", "")))

    def handle_endtag(self, tag):
        if tag == "form":
            self._form = None


def find_form(html, predicate):
    parser = FormParser()
    parser.feed(html)
    for form in parser.forms:
        if predicate(form):
            return form
    return None


def pin_dns(root_domain, ip):
    """Resolve every *.<root_domain> name to the droplet IP (a stale local DNS
    cache from an earlier droplet must not misdirect the test). TLS still
    uses the real hostname for SNI and certificate checks."""
    original = socket.getaddrinfo

    def getaddrinfo(host, *args, **kwargs):
        if host == root_domain or str(host).endswith("." + root_domain):
            host = ip
        return original(host, *args, **kwargs)

    socket.getaddrinfo = getaddrinfo


class Checks:
    def __init__(self):
        self.failed = False

    def record(self, name, ok, detail):
        detail = " ".join(str(detail).split())[:80]
        print(f"CHECK {name} {'PASS' if ok else 'FAIL'} {detail}", flush=True)
        if not ok:
            self.failed = True


def login(session, app_url, username, password, log):
    """Run the whole flow as <username>. Returns (final response, steps)."""
    r = session.get(app_url, timeout=30)
    login_page = r
    form = find_form(r.text, lambda f: "user_name" in f["fields"])
    if form is None:
        raise RuntimeError(f"no Forgejo login form at {r.url} (HTTP {r.status_code})")
    data = dict(form["fields"])
    data.update({"user_name": username, "password": password})
    r = session.post(urljoin(r.url, form["action"] or r.url), data=data, timeout=30)
    log(f"{username}: login POST -> {r.status_code} {r.url}")
    ## First authorization of the app shows Forgejo's grant page:
    grant = find_form(r.text, lambda f: "/login/oauth/grant" in f["action"])
    if grant is not None:
        data = dict(grant["fields"])
        data["granted"] = "true"
        r = session.post(urljoin(r.url, grant["action"]), data=data, timeout=30)
        log(f"{username}: grant POST -> {r.status_code} {r.url}")
    return login_page, r


def woodpecker_checks(args, checks, session, log, member_pw, outsider_pw):
    """Woodpecker logs users in with Forgejo itself (no oauth2-proxy). Only
    members of WOODPECKER_ORGS (the e2e org) may log in."""
    base = args.app_url.rstrip("/")

    def api_user(s):
        r = s.get(f"{base}/api/user", timeout=30)
        try:
            return r.status_code, r.json().get("login", "")
        except ValueError:
            return r.status_code, ""

    ## 1. Signed out: the API refuses:
    code, _ = api_user(session())
    checks.record("signed-out-api", code == 401, f"/api/user HTTP {code}")

    ## 2. An org member logs in through Forgejo and gets an API session:
    s = session()
    try:
        login(s, f"{base}/authorize", args.member, member_pw, log)
        code, user = api_user(s)
        checks.record("member-login", code == 200 and user == args.member,
                      f"/api/user HTTP {code} login={user or '-'}")
    except Exception as e:  # noqa: BLE001
        checks.record("member-login", False, e)

    ## 3. A Forgejo user outside the org can't log in:
    s = session()
    try:
        login(s, f"{base}/authorize", args.outsider, outsider_pw, log)
        code, user = api_user(s)
        checks.record("outsider-refused", code == 401 and not user,
                      f"/api/user HTTP {code} login={user or '-'}")
    except Exception as e:  # noqa: BLE001
        checks.record("outsider-refused", False, e)


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--target", choices=["oauth2-proxy", "woodpecker"],
                   default="oauth2-proxy",
                   help="oauth2-proxy: an app behind it; woodpecker: its own OAuth2 login")
    p.add_argument("--app-url", required=True)
    p.add_argument("--root-domain", required=True)
    p.add_argument("--ip", required=True, help="droplet IP to pin DNS to")
    p.add_argument("--member", required=True, help="user in the authorized team")
    p.add_argument("--outsider", required=True, help="user not in the team")
    p.add_argument("--insecure", action="store_true", help="accept staging certs")
    args = p.parse_args()

    member_pw = os.environ.get("E2E_MEMBER_PASSWORD", "")
    outsider_pw = os.environ.get("E2E_OUTSIDER_PASSWORD", "")
    if not member_pw or not outsider_pw:
        sys.exit("E2E_MEMBER_PASSWORD and E2E_OUTSIDER_PASSWORD must be set")

    pin_dns(args.root_domain, args.ip)
    if args.insecure:
        requests.packages.urllib3.disable_warnings()
    app_host = urlparse(args.app_url).hostname
    member_email = f"{args.member}@{args.root_domain}"

    def session():
        s = requests.Session()
        s.verify = not args.insecure
        return s

    def log(msg):
        print(msg, file=sys.stderr, flush=True)

    checks = Checks()
    if args.target == "woodpecker":
        woodpecker_checks(args, checks, session, log, member_pw, outsider_pw)
        sys.exit(1 if checks.failed else 0)

    ## 1. Signed out: the app redirects through oauth2-proxy to Forgejo's login:
    s = session()
    r = s.get(args.app_url, timeout=30)
    hops = " -> ".join(f"{h.status_code}:{urlparse(h.url).hostname}" for h in r.history)
    checks.record(
        "signed-out-redirect",
        urlparse(r.url).hostname != app_host and "/user/login" in r.url,
        f"{hops} -> {r.status_code} {urlparse(r.url).path}",
    )

    ## 2. Spoofed identity headers without a session must not get through:
    spoof = {
        "X-Auth-Request-Email": member_email,
        "X-Auth-Request-Groups": "e2e:allowed",
        "X_Auth_Request_Email": member_email,
        "X-Forwarded-User": member_email,
    }
    r = session().get(args.app_url, headers=spoof, allow_redirects=False, timeout=30)
    checks.record("spoofed-headers-rejected", r.status_code != 200,
                  f"HTTP {r.status_code}")

    ## 3. A member of the authorized team logs in and reaches the app:
    s = session()
    try:
        _, r = login(s, args.app_url, args.member, member_pw, log)
        ok = (r.status_code == 200 and urlparse(r.url).hostname == app_host
              and f"X-Auth-Request-Email: {member_email}" in r.text)
        checks.record("member-allowed", ok, f"HTTP {r.status_code} {r.url}")
        if not ok:
            log(r.text[:2000])
        ## 4. With a session, a spoofed email header is replaced by the real one:
        r = s.get(args.app_url, headers={"X-Auth-Request-Email": "attacker@example.com"},
                  timeout=30)
        checks.record(
            "session-header-not-spoofable",
            r.status_code == 200 and "attacker@example.com" not in r.text
            and member_email in r.text,
            f"HTTP {r.status_code}",
        )
    except Exception as e:  # noqa: BLE001 - report any failure as a check
        checks.record("member-allowed", False, e)

    ## 5. A valid Forgejo user outside the team is refused by the app:
    s = session()
    try:
        _, r = login(s, args.app_url, args.outsider, outsider_pw, log)
        checks.record("outsider-forbidden",
                      r.status_code == 403 and urlparse(r.url).hostname == app_host,
                      f"HTTP {r.status_code} {r.url}")
    except Exception as e:  # noqa: BLE001
        checks.record("outsider-forbidden", False, e)

    sys.exit(1 if checks.failed else 0)


if __name__ == "__main__":
    main()
