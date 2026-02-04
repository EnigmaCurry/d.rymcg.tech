#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["rich"]
# ///
"""
agent.py - System state checker for d.rymcg.tech agent readiness

DESCRIPTION
    This script checks whether the current system meets the prerequisites
    to run d.rymcg.tech. It produces machine-readable output suitable for
    consumption by an AI agent, including:
      - A checklist of completed/incomplete criteria
      - A list of next steps to achieve readiness

USAGE
    _scripts/agent.py [OPTIONS]

OPTIONS
    --json          Output in JSON format (default: plain text)
    --full          Show full checklist (default: only failures and next steps)
    --pager         Enable pager for terminal output
    --help          Show this help message

OUTPUT FORMAT
    The script outputs two sections:
      1. CHECKLIST - Each prerequisite with PASS/FAIL status
      2. NEXT_STEPS - Ordered list of actions needed to achieve readiness

CHECKLIST CRITERIA

    Workstation packages.

    d.rymcg.tech setup:
      - Repository cloned to expected path
      - d.rymcg.tech in PATH

    SSH configuration:
      - SSH agent running with key loaded, or detect a passwordless SSH key in ~/.ssh

    Docker context:
      - At least one remote Docker context exists
      - Current context is not "default" (local)
      - Current context is reachable (docker info succeeds)

    Server readiness (requires active context):
      - Docker daemon accessible on remote
      - Traefik installed and healthy
      - acme-dns installed and healthy (if DNS challenge needed)

EXIT CODES
    0 - All checks passed, system is ready
    1 - One or more checks failed, see NEXT_STEPS
    2 - Script error or invalid arguments

EXAMPLES
    # Basic check with human-readable output
    _scripts/agent.py

    # JSON output for agent consumption
    _scripts/agent.py --json

    # Full mode shows completed items in addition to todo items
    _scripts/agent.py --full

ENVIRONMENT VARIABLES
    D_RYMCG_TECH_PATH - Override expected repository path
                        (default: ~/git/vendor/enigmacurry/d.rymcg.tech)

SEE ALSO
    WORKSTATION_LINUX.md - Full workstation setup guide
    DOCKER.md - Docker server setup guide
    TOUR.md - Initial service installation guide
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

from rich.console import Console


@dataclass
class CheckResult:
    """Result of a single check."""

    name: str
    passed: bool
    message: str
    category: str
    next_step: str | None = None


@dataclass
class CheckReport:
    """Complete report of all checks."""

    results: list[CheckResult] = field(default_factory=list)

    @property
    def all_passed(self) -> bool:
        return all(r.passed for r in self.results)

    @property
    def next_steps(self) -> list[str]:
        return [r.next_step for r in self.results if not r.passed and r.next_step]

    def to_dict(self) -> dict:
        return {
            "checklist": [
                {
                    "name": r.name,
                    "category": r.category,
                    "passed": r.passed,
                    "message": r.message,
                }
                for r in self.results
            ],
            "next_steps": self.next_steps,
            "ready": self.all_passed,
        }


def run_command(cmd: list[str], timeout: int = 10) -> tuple[bool, str]:
    """Run a command and return (success, output)."""
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        )
        return result.returncode == 0, result.stdout.strip()
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except FileNotFoundError:
        return False, "Command not found"
    except Exception as e:
        return False, str(e)


def command_exists(cmd: str) -> bool:
    """Check if a command exists in PATH."""
    return shutil.which(cmd) is not None


def get_default_repo_path() -> Path:
    """Get the default d.rymcg.tech repository path."""
    env_path = os.environ.get("D_RYMCG_TECH_PATH")
    if env_path:
        return Path(env_path).expanduser()
    return Path.home() / "git" / "vendor" / "enigmacurry" / "d.rymcg.tech"


# =============================================================================
# Check functions
# =============================================================================

# Required commands to check
REQUIRED_COMMANDS = [
    "bash", "make", "git", "openssl", "htpasswd", "xdg-open", "jq", "sshfs",
    "wg", "curl", "inotifywait", "w3m", "sponge", "keychain", "ipcalc", "uv", "docker",
]


def get_install_packages_section() -> str:
    """Parse WORKSTATION_LINUX.md and extract the '## Install packages' section."""
    repo_path = get_default_repo_path()
    workstation_md = repo_path / "WORKSTATION_LINUX.md"

    if not workstation_md.is_file():
        return "See WORKSTATION_LINUX.md for installation instructions."

    content = workstation_md.read_text()
    lines = content.split("\n")

    in_section = False
    section_lines = []

    for line in lines:
        if line.startswith("## Install packages"):
            in_section = True
            section_lines.append(line)
        elif in_section:
            # Stop at next h2 section
            if line.startswith("## "):
                break
            section_lines.append(line)

    if section_lines:
        return "\n".join(section_lines).strip()
    return "See WORKSTATION_LINUX.md for installation instructions."


def check_workstation_packages() -> CheckResult:
    """Check all required workstation packages as a single check."""
    missing = [cmd for cmd in REQUIRED_COMMANDS if not command_exists(cmd)]

    if not missing:
        return CheckResult(
            name="Workstation packages",
            passed=True,
            message=f"All {len(REQUIRED_COMMANDS)} required packages installed",
            category="Workstation packages",
            next_step=None,
        )

    install_section = get_install_packages_section()
    return CheckResult(
        name="Workstation packages",
        passed=False,
        message=f"Missing: {', '.join(missing)}",
        category="Workstation packages",
        next_step=f"Install missing packages:\n\n{install_section}",
    )


def check_repo_cloned() -> CheckResult:
    """Check if d.rymcg.tech repo is cloned to expected path."""
    repo_path = get_default_repo_path()
    exists = repo_path.is_dir() and (repo_path / "README.md").is_file()
    return CheckResult(
        name="Repository cloned",
        passed=exists,
        message=f"Found at {repo_path}" if exists else f"Not found at {repo_path}",
        category="d.rymcg.tech setup",
        next_step=None
        if exists
        else f"git clone https://github.com/EnigmaCurry/d.rymcg.tech.git {repo_path}",
    )


def check_d_in_path() -> CheckResult:
    """Check if d.rymcg.tech is in PATH."""
    in_path = command_exists("d.rymcg.tech")
    repo_path = get_default_repo_path()
    scripts_path = repo_path / "_scripts" / "user"
    return CheckResult(
        name="d.rymcg.tech in PATH",
        passed=in_path,
        message="d.rymcg.tech command available" if in_path else "d.rymcg.tech not in PATH",
        category="d.rymcg.tech setup",
        next_step=None
        if in_path
        else f'Add to ~/.bashrc: export PATH=${{PATH}}:{scripts_path}',
    )


def check_ssh_keys() -> CheckResult:
    """Check for SSH agent with loaded keys or passwordless SSH key."""
    ssh_dir = Path.home() / ".ssh"
    key_files = ["id_ed25519", "id_rsa", "id_ecdsa"]

    # Check if SSH agent has keys loaded
    success, output = run_command(["ssh-add", "-l"])
    if success and "no identities" not in output.lower():
        return CheckResult(
            name="SSH key available",
            passed=True,
            message="SSH agent has keys loaded",
            category="SSH configuration",
            next_step=None,
        )

    # Check for passwordless SSH keys using ssh-keygen to test if key requires passphrase
    for key_name in key_files:
        key_path = ssh_dir / key_name
        if key_path.is_file():
            # Try to read the public key with empty passphrase - succeeds only if unencrypted
            success, _ = run_command(["ssh-keygen", "-y", "-P", "", "-f", str(key_path)])
            if success:
                return CheckResult(
                    name="SSH key available",
                    passed=True,
                    message=f"Passwordless SSH key found: {key_path}",
                    category="SSH configuration",
                    next_step=None,
                )

    # Check if any SSH keys exist at all
    existing_keys = [ssh_dir / k for k in key_files if (ssh_dir / k).is_file()]
    if existing_keys:
        return CheckResult(
            name="SSH key available",
            passed=False,
            message="SSH keys exist but are password-protected and not loaded in agent",
            category="SSH configuration",
            next_step="Run: eval $(keychain --quiet --eval --agents ssh id_ed25519) and enter your password",
        )

    return CheckResult(
        name="SSH key available",
        passed=False,
        message="No SSH keys found",
        category="SSH configuration",
        next_step="Create SSH key: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519",
    )


def check_remote_context_exists() -> CheckResult:
    """Check if at least one remote Docker context exists."""
    success, output = run_command(["docker", "context", "ls", "--format", "{{.Name}}"])
    if not success:
        return CheckResult(
            name="Remote Docker context exists",
            passed=False,
            message="Failed to list Docker contexts",
            category="Docker context",
            next_step="Ensure Docker CLI is installed and working",
        )

    contexts = [c.strip() for c in output.split("\n") if c.strip()]
    remote_contexts = [c for c in contexts if c != "default"]

    if remote_contexts:
        return CheckResult(
            name="Remote Docker context exists",
            passed=True,
            message=f"Remote contexts: {', '.join(remote_contexts)}",
            category="Docker context",
            next_step=None,
        )
    create_context_example = """\
```bash
set -euo pipefail

## Set these variables for your Docker server:
## (Replace these example values with your actual server details)
SSH_HOST=docker-server      # A short nickname for this server
SSH_HOSTNAME=192.168.1.100  # The IP address or domain name
SSH_USER=root               # The SSH username
SSH_PORT=22                 # The SSH port

## Append SSH host entry to ~/.ssh/config (if it doesn't exist):
grep -q "^Host ${SSH_HOST}$" ~/.ssh/config 2>/dev/null || cat <<EOF >> ~/.ssh/config

Host ${SSH_HOST}
    Hostname ${SSH_HOSTNAME}
    Port ${SSH_PORT}
    User ${SSH_USER}
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
EOF

## Create the Docker context:
docker context create ${SSH_HOST} --docker host=ssh://${SSH_HOST}
```"""
    return CheckResult(
        name="Remote Docker context exists",
        passed=False,
        message="No remote Docker contexts found",
        category="Docker context",
        next_step=f"Create a remote Docker context:\n\n{create_context_example}",
    )


def check_current_context_remote() -> CheckResult:
    """Check if current context is not the local default."""
    success, output = run_command(["docker", "context", "show"])
    if not success:
        return CheckResult(
            name="Current context is remote",
            passed=False,
            message="Failed to get current Docker context",
            category="Docker context",
            next_step="Ensure Docker CLI is installed and working",
        )

    current = output.strip()
    is_remote = current != "default"
    return CheckResult(
        name="Current context is remote",
        passed=is_remote,
        message=f"Current context: {current}" if is_remote else "Current context is 'default' (local)",
        category="Docker context",
        next_step=None if is_remote else "Switch context: d context (or docker context use <name>)",
    )


def check_context_reachable() -> CheckResult:
    """Check if current Docker context is reachable."""
    success, output = run_command(["docker", "context", "show"])
    if not success or output.strip() == "default":
        return CheckResult(
            name="Docker context reachable",
            passed=False,
            message="No remote context selected",
            category="Docker context",
            next_step="Select a remote context first",
        )

    context_name = output.strip()
    success, _ = run_command(["docker", "info"], timeout=15)
    return CheckResult(
        name="Docker context reachable",
        passed=success,
        message=f"Context '{context_name}' is reachable" if success else f"Cannot connect to '{context_name}'",
        category="Docker context",
        next_step=None if success else f"Check SSH access to the server for context '{context_name}'",
    )


def check_traefik_healthy() -> CheckResult:
    """Check if Traefik is installed and healthy on remote."""
    # First check if we can reach docker at all
    success, _ = run_command(["docker", "info"], timeout=15)
    if not success:
        return CheckResult(
            name="Traefik installed and healthy",
            passed=False,
            message="Cannot connect to Docker daemon",
            category="Server readiness",
            next_step="Ensure Docker context is reachable first",
        )

    # Check if traefik container exists and is healthy
    success, output = run_command(
        ["docker", "ps", "--filter", "name=traefik-traefik", "--format", "{{.Status}}"],
        timeout=15,
    )

    if not success:
        return CheckResult(
            name="Traefik installed and healthy",
            passed=False,
            message="Failed to check Traefik status",
            category="Server readiness",
            next_step="d make traefik config && d make traefik install",
        )

    if not output.strip():
        return CheckResult(
            name="Traefik installed and healthy",
            passed=False,
            message="Traefik container not found",
            category="Server readiness",
            next_step="d make traefik config && d make traefik install",
        )

    is_healthy = "healthy" in output.lower()
    return CheckResult(
        name="Traefik installed and healthy",
        passed=is_healthy,
        message=f"Traefik status: {output.strip()}" if is_healthy else f"Traefik unhealthy: {output.strip()}",
        category="Server readiness",
        next_step=None if is_healthy else "Check Traefik logs: d make traefik logs",
    )


def check_acme_dns_healthy() -> CheckResult:
    """Check if acme-dns is installed and healthy on remote."""
    # First check if we can reach docker at all
    success, _ = run_command(["docker", "info"], timeout=15)
    if not success:
        return CheckResult(
            name="acme-dns installed and healthy",
            passed=False,
            message="Cannot connect to Docker daemon",
            category="Server readiness",
            next_step="Ensure Docker context is reachable first",
        )

    # Check if acme-dns container exists and is healthy
    success, output = run_command(
        ["docker", "ps", "--filter", "name=acme-dns-acmedns", "--format", "{{.Status}}"],
        timeout=15,
    )

    if not success:
        return CheckResult(
            name="acme-dns installed and healthy",
            passed=False,
            message="Failed to check acme-dns status",
            category="Server readiness",
            next_step="d make acme-dns config && d make acme-dns install",
        )

    if not output.strip():
        return CheckResult(
            name="acme-dns installed and healthy",
            passed=False,
            message="acme-dns container not found",
            category="Server readiness",
            next_step="d make acme-dns config && d make acme-dns install",
        )

    is_healthy = "healthy" in output.lower()
    return CheckResult(
        name="acme-dns installed and healthy",
        passed=is_healthy,
        message=f"acme-dns status: {output.strip()}" if is_healthy else f"acme-dns unhealthy: {output.strip()}",
        category="Server readiness",
        next_step=None if is_healthy else "Check acme-dns logs: d make acme-dns logs",
    )


# =============================================================================
# Main
# =============================================================================


def run_all_checks() -> CheckReport:
    """Run all checks and return a report."""
    report = CheckReport()

    # Workstation packages
    report.results.append(check_workstation_packages())

    # d.rymcg.tech setup
    report.results.append(check_repo_cloned())
    report.results.append(check_d_in_path())

    # SSH configuration
    report.results.append(check_ssh_keys())

    # Docker context (cascading checks - only show next_step for first failure)
    remote_exists_result = check_remote_context_exists()
    report.results.append(remote_exists_result)

    if remote_exists_result.passed:
        current_remote_result = check_current_context_remote()
        report.results.append(current_remote_result)
    else:
        report.results.append(
            CheckResult(
                name="Current context is remote",
                passed=False,
                message="Skipped - no remote contexts exist",
                category="Docker context",
                next_step=None,  # Avoid redundant step
            )
        )
        current_remote_result = None

    if current_remote_result and current_remote_result.passed:
        context_reachable_result = check_context_reachable()
        report.results.append(context_reachable_result)
    else:
        report.results.append(
            CheckResult(
                name="Docker context reachable",
                passed=False,
                message="Skipped - no remote context selected",
                category="Docker context",
                next_step=None,  # Avoid redundant step
            )
        )
        context_reachable_result = None

    # Server readiness (only if context is reachable)
    if context_reachable_result and context_reachable_result.passed:
        report.results.append(check_traefik_healthy())
        report.results.append(check_acme_dns_healthy())
    else:
        report.results.append(
            CheckResult(
                name="Traefik installed and healthy",
                passed=False,
                message="Skipped - Docker context not reachable",
                category="Server readiness",
                next_step=None,  # Avoid redundant step
            )
        )
        report.results.append(
            CheckResult(
                name="acme-dns installed and healthy",
                passed=False,
                message="Skipped - Docker context not reachable",
                category="Server readiness",
                next_step=None,  # Avoid redundant step
            )
        )

    return report


def generate_markdown(report: CheckReport, full: bool = False) -> str:
    """Generate markdown report."""
    lines = []

    if full:
        lines.append("# d.rymcg.tech System Readiness Check")
        lines.append("")

        current_category = None
        for result in report.results:
            if result.category != current_category:
                current_category = result.category
                lines.append(f"## {current_category}")
                lines.append("")

            marker = "[x]" if result.passed else "[ ]"
            lines.append(f"- {marker} **{result.name}**")
            lines.append(f"  - {result.message}")
            lines.append("")

    if report.next_steps:
        lines.append("---")
        lines.append("")
        lines.append("## Next Steps")
        lines.append("")
        for i, step in enumerate(report.next_steps, 1):
            lines.append(f"{i}. {step}")
            lines.append("")

    if report.all_passed:
        lines.append("**Status: READY** - All checks passed!")
    else:
        failed_count = sum(1 for r in report.results if not r.passed)
        lines.append(f"**Status: NOT READY** - {failed_count} check(s) failed")

    return "\n".join(lines)


def print_report(report: CheckReport, full: bool = False, use_pager: bool = False) -> None:
    """Print report - uses pager with styles if requested and content is long enough."""
    markdown_text = generate_markdown(report, full)

    if use_pager and sys.stdout.isatty():
        # Force pager if --full, otherwise only use if content exceeds terminal height
        if full:
            needs_pager = True
        else:
            try:
                terminal_height = os.get_terminal_size().lines
                content_lines = markdown_text.count("\n") + 1
                needs_pager = content_lines > terminal_height
            except OSError:
                needs_pager = True

        console = Console()
        if needs_pager:
            with console.pager():
                console.print(markdown_text)
        else:
            print(markdown_text)
    else:
        print(markdown_text)


def print_json(report: CheckReport) -> None:
    """Print report in JSON format."""
    print(json.dumps(report.to_dict(), indent=2))


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="System state checker for d.rymcg.tech agent readiness",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--json", action="store_true", help="Output in JSON format"
    )
    parser.add_argument(
        "--full", action="store_true", help="Show full checklist (default: only failures and next steps)"
    )
    parser.add_argument(
        "--pager", action="store_true",
        help="Enable pager for terminal output"
    )

    args = parser.parse_args()

    try:
        report = run_all_checks()

        if args.json:
            print_json(report)
        else:
            print_report(report, full=args.full, use_pager=args.pager)

        return 0 if report.all_passed else 1

    except KeyboardInterrupt:
        print("\nInterrupted", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
