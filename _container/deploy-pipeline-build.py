# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Guided setup for the d-rymcg-tech Docker image build pipeline.

Walks through the steps needed to mirror the d.rymcg.tech GitHub repo
to Forgejo and configure Woodpecker CI to build the image automatically.
"""

import subprocess
import sys
import termios
import tty


def get_key():
    """Read a single keypress, returning a descriptive string."""
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)
        if ch == "\x1b":
            seq = sys.stdin.read(2)
            if seq == "[A":
                return "up"
            if seq == "[B":
                return "down"
            return "escape"
        if ch in ("\r", "\n"):
            return "enter"
        if ch == "\x7f":
            return "backspace"
        if ch == "\x03":
            raise KeyboardInterrupt
        if ch == "\x04":
            raise EOFError
        return ch
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


def prompt(text, default=""):
    """Prompt for input with an optional default value."""
    if default:
        result = input(f"{text} [{default}]: ").strip()
        return result if result else default
    return input(f"{text}: ").strip()


def get_ssh_keys():
    """Return list of SSH public keys from the agent."""
    try:
        result = subprocess.run(
            ["ssh-add", "-L"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            return [k.strip() for k in result.stdout.strip().splitlines() if k.strip()]
    except FileNotFoundError:
        pass
    return []


def build_steps(forgejo, woodpecker, owner, github_url):
    """Return the list of (title, body) step tuples."""
    keys = get_ssh_keys()
    if keys:
        key_lines = "\n".join(f"    {i+1}. {k}" for i, k in enumerate(keys))
        key_section = (
            f"  Your SSH public keys (add each one separately):\n\n{key_lines}"
        )
    else:
        key_section = "  (No keys found — is ssh-agent running?)"

    return [
        (
            "Deploy Forgejo",
            f"""\
  If Forgejo is not already deployed, deploy it now:

    d make forgejo config
    d make forgejo install

  Your Forgejo instance should be accessible at:

    https://{forgejo}""",
        ),
        (
            "Create 'woodpecker' organization",
            f"""\
  Woodpecker restricts login by Forgejo org membership (default org: woodpecker).
  Create this org so CI users can sign in.

  Log in as 'root' (or your admin account) and go to:

    https://{forgejo}/admin/orgs

  Click "New Organization" and name it: woodpecker""",
        ),
        (
            "Deploy Woodpecker CI",
            f"""\
  If Woodpecker CI is not already deployed, deploy it now:

    d make woodpecker config
    d make woodpecker install

  When prompted, select both the 'server' and 'agent' profiles.""",
        ),
        (
            "Create dedicated CI Forgejo account",
            f"""\
  Create a separate Forgejo account for CI operations (e.g. '{owner}').
  This keeps CI tokens scoped away from your personal admin account.

  Log in as 'root' (or your admin account) and go to:

    https://{forgejo}/admin/users

  Click "Create User Account" and create user: {owner}""",
        ),
        (
            "Add CI account to 'woodpecker' org",
            f"""\
  The CI account must be a member of the 'woodpecker' org to log in to Woodpecker.
  Forgejo requires adding members through a Team.

  Log in as 'root' (or your admin account) and go to:

    https://{forgejo}/org/woodpecker/teams

  1. Create a new team (e.g. "CI")
  2. Add '{owner}' as a member of that team""",
        ),
        (
            "Add SSH public key to CI account",
            f"""\
  Add your workstation's SSH public key(s) to the CI account so you can push.

  Log in as '{owner}' and go to:

    https://{forgejo}/user/settings/keys

  Forgejo requires adding keys one at a time.

{key_section}""",
        ),
        (
            "Create GitHub fine-grained Personal Access Token",
            f"""\
  Forgejo needs a GitHub token to authenticate when pulling the mirror.
  Create a fine-grained Personal Access Token on GitHub:

    https://github.com/settings/personal-access-tokens

  - Click "Generate new token"
  - Token name: e.g. "forgejo-mirror"
  - Expiration: No expiration
  - Repository access: select "Public Repositories (read-only)"
  - No additional permissions are needed
  - Click "Generate token" and copy it for the next step""",
        ),
        (
            "Create GitHub pull mirror",
            f"""\
  Create a mirror of the d.rymcg.tech repo so Forgejo tracks upstream changes.

  Log in as '{owner}' and go to:

    https://{forgejo}/repo/migrate

  - Select GitHub as the source
  - Repo URL: {github_url}
  - Paste the Personal Access Token from the previous step
  - Check "This repository will be a mirror"
  - Click "Migrate Repository"

  The mirror polls GitHub on an interval (default 8h). A later step
  sets up a webhook for instant sync.""",
        ),
        (
            "Create Forgejo API token for GitHub webhook (optional)",
            f"""\
  This step is optional — skip it if you don't own the upstream GitHub repo
  or don't need instant mirror sync.

  Still logged in as '{owner}', go to:

    https://{forgejo}/user/settings/applications

  Create a token with scope: repository:write

  Then add a webhook on the GitHub repo (Settings -> Webhooks -> Add webhook):

    Payload URL:
      https://{forgejo}/api/v1/repos/{owner}/d.rymcg.tech/mirror-sync?token=YOUR_TOKEN

    Content type: application/json
    Secret: (leave blank)
    Events: Just the push event""",
        ),
        (
            "Activate mirror repo in Woodpecker",
            f"""\
  Log in to Woodpecker as '{owner}':

    https://{woodpecker}

  - Click "Add repository"
  - Find the d.rymcg.tech mirror repo in the list
  - Click "Enable" to activate it""",
        ),
        (
            "Set repo as trusted in Woodpecker",
            f"""\
  Privileged Docker builds require the repo to be marked as trusted.
  Only Woodpecker admins can change trust levels.

  IMPORTANT: You must log in to Woodpecker AS AN ADMIN — as 'root',
  not as '{owner}' — to change trust levels. Log out of Forgejo first,
  since Woodpecker uses Forgejo for authentication.

  Copy the two export statements from the CLI and API page:

    https://{woodpecker}/user/cli-and-api

  Paste them into your terminal:

    export WOODPECKER_SERVER=https://{woodpecker}
    export WOODPECKER_TOKEN=<your-token>

  Then run:

    d.rymcg.tech make woodpecker trusted

  Select the repository and choose which trust levels to enable.
  For Docker image builds, select at least "security".

  When done, reset your API token on the same page for security.""",
        ),
        (
            "Create Forgejo API token for registry access",
            f"""\
  The build pipeline needs to push Docker images to the Forgejo container registry.

  Log in as '{owner}' and go to:

    https://{forgejo}/user/settings/applications

  Create a token with scope: write:package

  Save this token — you will need it in the next step as the 'registry_password' secret.

  When done, log out of Forgejo and Woodpecker, then log back in to
  Woodpecker as '{owner}'.""",
        ),
        (
            "Add Woodpecker secrets",
            f"""\
  In Woodpecker (logged in as '{owner}'):

    https://{woodpecker}

  In the Woodpecker project settings for the mirror repo
  (https://{woodpecker}/repos/X/settings/secrets), add these secrets:

    registry          — {forgejo}
    registry_username — {owner}
    registry_password — the Forgejo token with write:package scope (from the previous step)

  When creating each secret, enable all the events you need:
  push, manual, and cron.

  The build pipeline (.woodpecker/build.yaml) triggers on push to the
  workstation-ci branch, building the image only if one doesn't exist
  for the current commit SHA.""",
        ),
    ]


def display_step(index, total, title, body):
    """Display a single step."""
    print(f"\n{'=' * 60}")
    print(f"  Step {index + 1} of {total}: {title}")
    print(f"{'=' * 60}\n")
    print(body)
    print()
    if index < total - 1:
        print("  [Enter] Next step  |  [Backspace] Previous step  |  [q] Quit")
    elif index == total - 1:
        print("  [Enter] Finish  |  [Backspace] Previous step  |  [q] Quit")


def main():
    print("=" * 60)
    print("  Build pipeline setup for d-rymcg-tech Docker image")
    print("=" * 60)
    print()
    print("  This script walks you through setting up the build pipeline")
    print("  for the d-rymcg-tech Docker image. It mirrors the d.rymcg.tech")
    print("  GitHub repo to your Forgejo instance and configures Woodpecker")
    print("  CI to automatically build and push the image to your registry.")
    print()
    print("  This is a guidance-only tool — it shows you what to do at each")
    print("  step with personalized URLs, but does not automate any actions.")
    print()

    forgejo = ""
    while not forgejo:
        forgejo = prompt("Forgejo hostname (e.g. git.example.com)")

    woodpecker = ""
    while not woodpecker:
        woodpecker = prompt("Woodpecker hostname (e.g. woodpecker.example.com)")

    github_url = prompt(
        "GitHub repo URL",
        "https://github.com/EnigmaCurry/d.rymcg.tech",
    )

    # Derive default owner from GitHub URL: e.g. "EnigmaCurry" + "github" -> "enigmacurry-github"
    default_owner = "enigmacurry-github"
    try:
        from urllib.parse import urlparse
        parsed = urlparse(github_url)
        parts = parsed.path.strip("/").split("/")
        if len(parts) >= 1 and parts[0]:
            default_owner = f"{parts[0].lower()}-{parsed.hostname.split('.')[0]}"
    except Exception:
        pass

    print()
    print("  Choose a name for the dedicated Forgejo CI account you will create.")
    print("  This account should be dedicated to syncing from GitHub, so a name")
    print(f"  like '{default_owner}' is appropriate. The account will be created")
    print("  in a later step.")
    print()
    owner = ""
    while not owner:
        owner = prompt("Repository owner / CI account name", default_owner)

    steps = build_steps(forgejo, woodpecker, owner, github_url)
    total = len(steps)
    index = 0

    while 0 <= index < total:
        title, body = steps[index]
        display_step(index, total, title, body)

        key = get_key()
        if key == "enter":
            index += 1
        elif key == "backspace":
            if index > 0:
                index -= 1
        elif key in ("q", "escape"):
            print("\nAborted.")
            sys.exit(130)

    print(f"\n{'=' * 60}")
    print("  Setup complete!")
    print(f"{'=' * 60}")
    print()
    print("  Your build pipeline should now be configured. Push to the")
    print("  workstation-ci branch to trigger the first build.")
    print()


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        print("\nAborted.")
        sys.exit(130)
