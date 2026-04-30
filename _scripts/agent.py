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
    _scripts/agent.py [COMMAND] [OPTIONS]

COMMANDS
    check               Run readiness checks (default if no command given)
    list                List all configured contexts (JSON)
    current             Show current context configuration (JSON)
    delete NAME         Delete a context (Docker context, SSH config, saved config)
    clear               Delete all saved state and start fresh

CHECK OPTIONS
    --context NAME       Set or switch to context NAME (required on first run)
    --ssh-hostname HOST  SSH hostname or IP address
    --ssh-user USER      SSH username
    --ssh-port PORT      SSH port
    --root-domain DOMAIN Root domain (e.g., example.com)
    --proxy-protocol BOOL       Server behind proxy using proxy protocol (true/false)
    --save-cleartext-passwords BOOL  Save cleartext passwords (true/false)
    --role ROLE          Server role: 'public' (datacenter/open ports) or 'private' (NAT/no public ports)
    --json               Output in JSON format (default: plain text)
    --full               Show full checklist (default: only failures and next steps)
    --pager              Enable pager for terminal output
    --help               Show this help message

OUTPUT FORMAT
    The script outputs two sections:
      1. CHECKLIST - Each prerequisite with PASS/FAIL status
      2. NEXT_STEPS - Ordered list of actions needed to achieve readiness

CHECKLIST CRITERIA

    Workstation packages.

    d.rymcg.tech setup:
      - Repository cloned to expected path
      - d.rymcg.tech in PATH
      - script-wizard installed
      - Root .env_{CONTEXT} file configured

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
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from rich.console import Console


CACHE_DIR = Path.home() / ".local" / "d.rymcg.tech"
CONTEXTS_FILE = CACHE_DIR / "agent.contexts.json"

# Required fields for a context configuration
CONTEXT_FIELDS = ["ssh_hostname", "ssh_user", "ssh_port", "root_domain", "proxy_protocol", "save_cleartext_passwords", "role"]

# Valid server roles
VALID_ROLES = ["public", "private"]


@dataclass
class ContextConfig:
    """Configuration for a Docker context."""
    context_name: str
    ssh_hostname: str
    ssh_user: str
    ssh_port: int
    root_domain: str
    proxy_protocol: bool
    save_cleartext_passwords: bool
    role: str

    def to_dict(self) -> dict:
        return {
            "ssh_hostname": self.ssh_hostname,
            "ssh_user": self.ssh_user,
            "ssh_port": self.ssh_port,
            "root_domain": self.root_domain,
            "proxy_protocol": self.proxy_protocol,
            "save_cleartext_passwords": self.save_cleartext_passwords,
            "role": self.role,
        }

    @classmethod
    def from_dict(cls, context_name: str, data: dict) -> "ContextConfig":
        return cls(
            context_name=context_name,
            ssh_hostname=data.get("ssh_hostname"),
            ssh_user=data.get("ssh_user"),
            ssh_port=data.get("ssh_port"),
            root_domain=data.get("root_domain"),
            proxy_protocol=data.get("proxy_protocol"),
            save_cleartext_passwords=data.get("save_cleartext_passwords"),
            role=data.get("role"),
        )


def load_contexts_file() -> dict:
    """Load the contexts JSON file."""
    if not CONTEXTS_FILE.exists():
        return {"current": None, "contexts": {}}
    try:
        return json.loads(CONTEXTS_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return {"current": None, "contexts": {}}


def save_contexts_file(data: dict) -> None:
    """Save the contexts JSON file."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    CONTEXTS_FILE.write_text(json.dumps(data, indent=2))


def get_current_context_name() -> str | None:
    """Get the current context name."""
    data = load_contexts_file()
    return data.get("current")


def set_current_context(context_name: str) -> None:
    """Set the current context name."""
    data = load_contexts_file()
    data["current"] = context_name
    save_contexts_file(data)


def get_context_config(context_name: str) -> ContextConfig | None:
    """Get configuration for a specific context."""
    data = load_contexts_file()
    contexts = data.get("contexts", {})
    if context_name not in contexts:
        return None
    try:
        return ContextConfig.from_dict(context_name, contexts[context_name])
    except (KeyError, TypeError):
        return None


def save_context_config(config: ContextConfig) -> None:
    """Save configuration for a context."""
    data = load_contexts_file()
    if "contexts" not in data:
        data["contexts"] = {}
    data["contexts"][config.context_name] = config.to_dict()
    data["current"] = config.context_name
    save_contexts_file(data)


def get_docker_contexts() -> list[str]:
    """Get list of Docker context names (excluding 'default')."""
    success, output = run_command(["docker", "context", "ls", "--format", "{{.Name}}"])
    if not success:
        return []
    return [c.strip() for c in output.split("\n") if c.strip() and c.strip() != "default"]


def discover_ssh_config(context_name: str) -> dict:
    """Discover SSH configuration from ~/.ssh/config for a given host.

    Returns a dict with discovered values (ssh_hostname, ssh_user, ssh_port).
    Missing values are not included in the dict.
    """
    ssh_config = Path.home() / ".ssh" / "config"
    if not ssh_config.exists():
        return {}

    try:
        content = ssh_config.read_text()
    except OSError:
        return {}

    import re

    # Find the Host block for this context
    # Match "Host <name>" followed by indented config lines
    pattern = rf'^Host\s+{re.escape(context_name)}\s*$\n((?:[ \t]+[^\n]*\n)*)'
    match = re.search(pattern, content, re.MULTILINE)
    if not match:
        return {}

    block = match.group(1)
    result = {}

    # Parse the indented lines for Hostname, User, Port
    for line in block.split('\n'):
        line = line.strip()
        if not line:
            continue

        # Match key-value pairs
        kv_match = re.match(r'^(\w+)\s+(.+)$', line)
        if not kv_match:
            continue

        key, value = kv_match.groups()
        key_lower = key.lower()

        if key_lower == 'hostname':
            result['ssh_hostname'] = value
        elif key_lower == 'user':
            result['ssh_user'] = value
        elif key_lower == 'port':
            try:
                result['ssh_port'] = int(value)
            except ValueError:
                pass

    return result


def get_missing_context_fields(context_name: str) -> list[str]:
    """Get list of missing fields for a context."""
    data = load_contexts_file()
    contexts = data.get("contexts", {})
    if context_name not in contexts:
        return CONTEXT_FIELDS.copy()
    ctx = contexts[context_name]
    missing = []
    for field in CONTEXT_FIELDS:
        if field not in ctx or ctx[field] is None or ctx[field] == "":
            missing.append(field)
    return missing


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
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "checklist": [
                {
                    "name": r.name,
                    "category": r.category,
                    "passed": r.passed,
                    "message": r.message,
                    "next_step": r.next_step,
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


def check_script_wizard_installed() -> CheckResult:
    """Check if script-wizard is installed, installing it if needed."""
    # Run the install command with --yes to ensure script-wizard is installed
    success, output = run_command(
        ["d.rymcg.tech", "script", "install_script-wizard", "--yes"],
        timeout=60,
    )
    if success:
        return CheckResult(
            name="script-wizard installed",
            passed=True,
            message="script-wizard is installed",
            category="d.rymcg.tech setup",
            next_step=None,
        )
    return CheckResult(
        name="script-wizard installed",
        passed=False,
        message=f"Failed to install script-wizard: {output}",
        category="d.rymcg.tech setup",
        next_step="d.rymcg.tech script install_script-wizard --yes",
    )


def check_env_file_configured(config: ContextConfig) -> CheckResult:
    """Check if .env_{CONTEXT} file exists and is properly configured."""
    repo_path = get_default_repo_path()
    env_dist = repo_path / ".env-dist"
    env_file = repo_path / f".env_{config.context_name}"

    if not env_dist.exists():
        return CheckResult(
            name="Root .env file configured",
            passed=False,
            message=f".env-dist not found at {env_dist}",
            category="d.rymcg.tech setup",
            next_step="Ensure d.rymcg.tech repository is properly cloned",
        )

    # Check if .env_{CONTEXT} exists
    if not env_file.exists():
        # Create it from .env-dist
        try:
            content = env_dist.read_text()
            # Replace default values with configured values
            content = content.replace(
                "ROOT_DOMAIN=d.example.com",
                f"ROOT_DOMAIN={config.root_domain}",
            )
            content = content.replace(
                "DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON=false",
                f"DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON={'true' if config.save_cleartext_passwords else 'false'}",
            )
            content = content.replace(
                "DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL=0",
                f"DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL={'true' if config.proxy_protocol else 'false'}",
            )
            content = content.replace(
                "DEFAULT_CLI_ROUTE_LAYER_4_PROXY_PROTOCOL=0",
                f"DEFAULT_CLI_ROUTE_LAYER_4_PROXY_PROTOCOL={'true' if config.proxy_protocol else 'false'}",
            )
            env_file.write_text(content)
            return CheckResult(
                name="Root .env file configured",
                passed=True,
                message=f"Created {env_file.name} with ROOT_DOMAIN={config.root_domain}",
                category="d.rymcg.tech setup",
                next_step=None,
            )
        except OSError as e:
            return CheckResult(
                name="Root .env file configured",
                passed=False,
                message=f"Failed to create {env_file.name}: {e}",
                category="d.rymcg.tech setup",
                next_step=f"Manually copy .env-dist to {env_file.name} and configure ROOT_DOMAIN",
            )

    # File exists, verify ROOT_DOMAIN is set correctly
    try:
        content = env_file.read_text()
        if f"ROOT_DOMAIN={config.root_domain}" in content:
            return CheckResult(
                name="Root .env file configured",
                passed=True,
                message=f"{env_file.name} configured with ROOT_DOMAIN={config.root_domain}",
                category="d.rymcg.tech setup",
                next_step=None,
            )
        elif "ROOT_DOMAIN=d.example.com" in content:
            # Update the placeholder - this is a fresh file from .env-dist
            content = content.replace(
                "ROOT_DOMAIN=d.example.com",
                f"ROOT_DOMAIN={config.root_domain}",
            )
            content = content.replace(
                "DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON=false",
                f"DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON={'true' if config.save_cleartext_passwords else 'false'}",
            )
            content = content.replace(
                "DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL=0",
                f"DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL={'true' if config.proxy_protocol else 'false'}",
            )
            content = content.replace(
                "DEFAULT_CLI_ROUTE_LAYER_4_PROXY_PROTOCOL=0",
                f"DEFAULT_CLI_ROUTE_LAYER_4_PROXY_PROTOCOL={'true' if config.proxy_protocol else 'false'}",
            )
            env_file.write_text(content)
            return CheckResult(
                name="Root .env file configured",
                passed=True,
                message=f"Updated {env_file.name} with ROOT_DOMAIN={config.root_domain}",
                category="d.rymcg.tech setup",
                next_step=None,
            )
        else:
            return CheckResult(
                name="Root .env file configured",
                passed=True,
                message=f"{env_file.name} exists (ROOT_DOMAIN may differ from context config)",
                category="d.rymcg.tech setup",
                next_step=None,
            )
    except OSError as e:
        return CheckResult(
            name="Root .env file configured",
            passed=False,
            message=f"Failed to read {env_file.name}: {e}",
            category="d.rymcg.tech setup",
            next_step=f"Check permissions on {env_file}",
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


def check_ssh_host_configured(config: ContextConfig) -> CheckResult:
    """Check if the specified SSH host is configured in ~/.ssh/config, adding it if needed."""
    ssh_dir = Path.home() / ".ssh"
    ssh_config = ssh_dir / "config"

    def get_host_entry() -> str:
        return f"""
Host {config.context_name}
    Hostname {config.ssh_hostname}
    Port {config.ssh_port}
    User {config.ssh_user}
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
"""

    def add_host_entry() -> tuple[bool, str]:
        """Add the SSH host entry to config. Returns (success, message)."""
        try:
            # Ensure ~/.ssh directory exists with correct permissions
            ssh_dir.mkdir(mode=0o700, exist_ok=True)

            # Read existing content or start fresh
            if ssh_config.exists():
                content = ssh_config.read_text()
            else:
                content = ""

            # Append the new host entry
            content += get_host_entry()
            ssh_config.write_text(content)

            # Ensure config file has correct permissions
            ssh_config.chmod(0o600)

            return True, f"Added SSH host '{config.context_name}' to ~/.ssh/config"
        except OSError as e:
            return False, f"Failed to update ~/.ssh/config: {e}"

    # Check if host is already configured
    if ssh_config.exists():
        try:
            content = ssh_config.read_text()
            import re
            hosts = re.findall(r'^Host\s+(\S+)', content, re.MULTILINE)

            if config.context_name in hosts:
                return CheckResult(
                    name="SSH host configured",
                    passed=True,
                    message=f"SSH host '{config.context_name}' is configured",
                    category="SSH configuration",
                    next_step=None,
                )
        except OSError:
            pass

    # Host not configured, add it
    success, message = add_host_entry()
    if success:
        return CheckResult(
            name="SSH host configured",
            passed=True,
            message=message,
            category="SSH configuration",
            next_step=None,
        )
    return CheckResult(
        name="SSH host configured",
        passed=False,
        message=message,
        category="SSH configuration",
        next_step="Manually add SSH host entry to ~/.ssh/config",
    )


def check_remote_context_exists(config: ContextConfig) -> CheckResult:
    """Check if the specified Docker context exists, creating it if needed."""
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

    if config.context_name in contexts:
        return CheckResult(
            name="Remote Docker context exists",
            passed=True,
            message=f"Docker context '{config.context_name}' exists",
            category="Docker context",
            next_step=None,
        )

    # Context doesn't exist, create it
    success, output = run_command([
        "docker", "context", "create", config.context_name,
        "--docker", f"host=ssh://{config.context_name}"
    ])
    if success:
        return CheckResult(
            name="Remote Docker context exists",
            passed=True,
            message=f"Created Docker context '{config.context_name}'",
            category="Docker context",
            next_step=None,
        )
    return CheckResult(
        name="Remote Docker context exists",
        passed=False,
        message=f"Failed to create Docker context: {output}",
        category="Docker context",
        next_step="Ensure Docker CLI is installed and SSH host is configured",
    )


def check_current_context_remote(config: ContextConfig) -> CheckResult:
    """Check if current context matches the configured context, switching if needed."""
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

    # If already on the correct context, we're good
    if current == config.context_name:
        return CheckResult(
            name="Current context is remote",
            passed=True,
            message=f"Current context: {current}",
            category="Docker context",
            next_step=None,
        )

    # Switch to the configured context
    success, output = run_command(["docker", "context", "use", config.context_name])
    if success:
        return CheckResult(
            name="Current context is remote",
            passed=True,
            message=f"Switched to context '{config.context_name}'",
            category="Docker context",
            next_step=None,
        )
    return CheckResult(
        name="Current context is remote",
        passed=False,
        message=f"Failed to switch to context '{config.context_name}': {output}",
        category="Docker context",
        next_step=f"docker context use {config.context_name}",
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
            next_step="Configure and install Traefik non-interactively (see AGENTS.md 'Configure Traefik' section)",
        )

    if not output.strip():
        return CheckResult(
            name="Traefik installed and healthy",
            passed=False,
            message="Traefik container not found",
            category="Server readiness",
            next_step="Configure and install Traefik non-interactively (see AGENTS.md 'Configure Traefik' section)",
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


def run_all_checks(context_config: ContextConfig) -> CheckReport:
    """Run all checks and return a report.

    Args:
        context_config: The context configuration to use.
    """
    report = CheckReport()

    # Workstation packages
    report.results.append(check_workstation_packages())

    # d.rymcg.tech setup
    report.results.append(check_repo_cloned())
    d_in_path_result = check_d_in_path()
    report.results.append(d_in_path_result)

    # script-wizard installation (requires d.rymcg.tech in PATH)
    if d_in_path_result.passed:
        report.results.append(check_script_wizard_installed())
    else:
        report.results.append(
            CheckResult(
                name="script-wizard installed",
                passed=False,
                message="Skipped - d.rymcg.tech not in PATH",
                category="d.rymcg.tech setup",
                next_step=None,
            )
        )

    # Root .env file configuration
    report.results.append(check_env_file_configured(context_config))

    # SSH configuration
    report.results.append(check_ssh_keys())

    # SSH host configuration (cascading - must pass before Docker context checks)
    ssh_host_result = check_ssh_host_configured(context_config)
    report.results.append(ssh_host_result)

    if not ssh_host_result.passed:
        # Skip all Docker context checks if SSH host not configured
        report.results.append(
            CheckResult(
                name="Remote Docker context exists",
                passed=False,
                message="Skipped - SSH host not configured",
                category="Docker context",
                next_step=None,
            )
        )
        report.results.append(
            CheckResult(
                name="Current context is remote",
                passed=False,
                message="Skipped - SSH host not configured",
                category="Docker context",
                next_step=None,
            )
        )
        report.results.append(
            CheckResult(
                name="Docker context reachable",
                passed=False,
                message="Skipped - SSH host not configured",
                category="Docker context",
                next_step=None,
            )
        )
        report.results.append(
            CheckResult(
                name="Traefik installed and healthy",
                passed=False,
                message="Skipped - SSH host not configured",
                category="Server readiness",
                next_step=None,
            )
        )
        report.results.append(
            CheckResult(
                name="acme-dns installed and healthy",
                passed=False,
                message="Skipped - SSH host not configured",
                category="Server readiness",
                next_step=None,
            )
        )
        return report

    # Docker context (cascading checks - only show next_step for first failure)
    remote_exists_result = check_remote_context_exists(context_config)
    report.results.append(remote_exists_result)

    if remote_exists_result.passed:
        current_remote_result = check_current_context_remote(context_config)
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
        if context_config.role == "private":
            report.results.append(
                CheckResult(
                    name="acme-dns installed and healthy",
                    passed=True,
                    message="Skipped - private server uses external acme-dns",
                    category="Server readiness",
                    next_step=None,
                )
            )
        else:
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


def cmd_clear(args) -> int:
    """Handle 'clear' subcommand."""
    if CACHE_DIR.exists():
        import shutil as sh
        sh.rmtree(CACHE_DIR)
        print(f"Deleted {CACHE_DIR}")
    else:
        print(f"Nothing to clear ({CACHE_DIR} does not exist)")
    return 0


def cmd_delete(args) -> int:
    """Handle 'delete' subcommand."""
    context_name = args.name
    deleted_items = []

    # Check if Docker context exists
    success, output = run_command(["docker", "context", "ls", "--format", "{{.Name}}"])
    if success and context_name in output.split():
        # Switch to default if this is the current context
        current_success, current = run_command(["docker", "context", "show"])
        if current_success and current.strip() == context_name:
            run_command(["docker", "context", "use", "default"])
        # Delete Docker context
        success, _ = run_command(["docker", "context", "rm", context_name])
        if success:
            deleted_items.append(f"Docker context '{context_name}'")

    # Remove SSH config entry
    ssh_config = Path.home() / ".ssh" / "config"
    if ssh_config.exists():
        try:
            content = ssh_config.read_text()
            import re
            # Match the Host block and all indented lines that follow
            pattern = rf'\n?Host {re.escape(context_name)}\n(?:[ \t]+[^\n]*\n)*'
            new_content, count = re.subn(pattern, '', content)
            if count > 0:
                ssh_config.write_text(new_content)
                deleted_items.append(f"SSH config entry '{context_name}'")
        except OSError as e:
            print(f"Warning: Failed to update SSH config: {e}", file=sys.stderr)

    # Remove from agent.contexts.json
    data = load_contexts_file()
    if context_name in data.get("contexts", {}):
        del data["contexts"][context_name]
        if data.get("current") == context_name:
            data["current"] = None
        save_contexts_file(data)
        deleted_items.append(f"Saved config for '{context_name}'")

    if deleted_items:
        print("Deleted:")
        for item in deleted_items:
            print(f"  - {item}")
    else:
        print(f"Context '{context_name}' not found")
    return 0


def cmd_list(args) -> int:
    """Handle 'list' subcommand."""
    # Get saved config
    saved_data = load_contexts_file()
    saved_contexts = saved_data.get("contexts", {})

    # Discover all Docker contexts
    docker_contexts = get_docker_contexts()

    # Build merged context list and save discovered values
    all_context_names = set(docker_contexts) | set(saved_contexts.keys())
    merged_contexts = {}
    contexts_to_save = {}

    for name in sorted(all_context_names):
        # Start with saved config if exists
        if name in saved_contexts:
            ctx = dict(saved_contexts[name])
        else:
            ctx = {}

        # Discover SSH config and fill in missing values
        discovered = discover_ssh_config(name)
        updated = False
        if 'ssh_hostname' not in ctx or ctx.get('ssh_hostname') is None:
            if discovered.get('ssh_hostname'):
                ctx['ssh_hostname'] = discovered['ssh_hostname']
                updated = True
        if 'ssh_user' not in ctx or ctx.get('ssh_user') is None:
            if discovered.get('ssh_user'):
                ctx['ssh_user'] = discovered['ssh_user']
                updated = True
        if 'ssh_port' not in ctx or ctx.get('ssh_port') is None:
            if discovered.get('ssh_port'):
                ctx['ssh_port'] = discovered['ssh_port']
                updated = True

        # Save context without docker_context_exists (that's computed)
        save_ctx = {k: v for k, v in ctx.items() if k != 'docker_context_exists' and v is not None}
        if save_ctx:
            contexts_to_save[name] = save_ctx

        # Mark if this context exists in Docker (for display only)
        ctx['docker_context_exists'] = name in docker_contexts
        merged_contexts[name] = ctx

    # Save discovered values
    if contexts_to_save:
        saved_data["contexts"] = contexts_to_save
        save_contexts_file(saved_data)

    output = {
        "current": saved_data.get("current"),
        "contexts": merged_contexts,
    }
    print(json.dumps(output, indent=2))
    return 0


def cmd_current(args) -> int:
    """Handle 'current' subcommand."""
    current = get_current_context_name()
    if not current:
        print("Error: No current context set.", file=sys.stderr)
        print("Run 'check --context NAME' to set a context first.", file=sys.stderr)
        return 2
    config = get_context_config(current)
    if not config:
        print(f"Error: Context '{current}' has no saved configuration.", file=sys.stderr)
        return 2
    output = {
        "context_name": config.context_name,
        "ssh_hostname": config.ssh_hostname,
        "ssh_user": config.ssh_user,
        "ssh_port": config.ssh_port,
        "root_domain": config.root_domain,
        "proxy_protocol": config.proxy_protocol,
        "save_cleartext_passwords": config.save_cleartext_passwords,
        "role": config.role,
    }
    print(json.dumps(output, indent=2))
    return 0


def cmd_check(args) -> int:
    """Handle 'check' subcommand."""
    # Require --context to be specified explicitly
    if not args.context:
        # Show available Docker contexts
        docker_contexts = get_docker_contexts()
        print("Error: No context specified. Use --context NAME.", file=sys.stderr)
        if docker_contexts:
            print(f"\nAvailable Docker contexts: {', '.join(docker_contexts)}", file=sys.stderr)
            print(f"\nExample: agent.py check --context {docker_contexts[0]}", file=sys.stderr)
        else:
            print("\nNo Docker contexts found. Create one with:", file=sys.stderr)
            print("  agent.py check --context NAME --ssh-hostname HOST --ssh-user USER --ssh-port PORT --root-domain DOMAIN --proxy-protocol false --save-cleartext-passwords false --role public", file=sys.stderr)
        return 2

    context_name = args.context

    # Load existing config or create new one
    existing_config = get_context_config(context_name)

    # Try to discover SSH config from ~/.ssh/config
    discovered_ssh = discover_ssh_config(context_name)

    # Build config from args, existing values, and discovered values (in priority order)
    ssh_hostname = args.ssh_hostname or (existing_config.ssh_hostname if existing_config else None) or discovered_ssh.get('ssh_hostname')
    ssh_user = args.ssh_user or (existing_config.ssh_user if existing_config else None) or discovered_ssh.get('ssh_user')
    ssh_port = args.ssh_port or (existing_config.ssh_port if existing_config else None) or discovered_ssh.get('ssh_port')
    root_domain = args.root_domain or (existing_config.root_domain if existing_config else None)
    # For booleans, args.X is None if not provided, so we check explicitly
    if args.proxy_protocol is not None:
        proxy_protocol = args.proxy_protocol
    elif existing_config and existing_config.proxy_protocol is not None:
        proxy_protocol = existing_config.proxy_protocol
    else:
        proxy_protocol = None
    if args.save_cleartext_passwords is not None:
        save_cleartext_passwords = args.save_cleartext_passwords
    elif existing_config and existing_config.save_cleartext_passwords is not None:
        save_cleartext_passwords = existing_config.save_cleartext_passwords
    else:
        save_cleartext_passwords = None
    role = args.role or (existing_config.role if existing_config and existing_config.role else None)

    # Save partial config (discovered values) even if some fields are missing
    partial_config = {}
    if ssh_hostname:
        partial_config['ssh_hostname'] = ssh_hostname
    if ssh_user:
        partial_config['ssh_user'] = ssh_user
    if ssh_port:
        partial_config['ssh_port'] = ssh_port
    if root_domain:
        partial_config['root_domain'] = root_domain
    if proxy_protocol is not None:
        partial_config['proxy_protocol'] = proxy_protocol
    if save_cleartext_passwords is not None:
        partial_config['save_cleartext_passwords'] = save_cleartext_passwords
    if role:
        partial_config['role'] = role

    if partial_config:
        data = load_contexts_file()
        if "contexts" not in data:
            data["contexts"] = {}
        # Merge with existing config
        if context_name in data["contexts"]:
            data["contexts"][context_name].update(partial_config)
        else:
            data["contexts"][context_name] = partial_config
        save_contexts_file(data)

    # Check for missing fields
    missing = []
    if not ssh_hostname:
        missing.append("--ssh-hostname")
    if not ssh_user:
        missing.append("--ssh-user")
    if not ssh_port:
        missing.append("--ssh-port")
    if not root_domain:
        missing.append("--root-domain")
    if proxy_protocol is None:
        missing.append("--proxy-protocol")
    if save_cleartext_passwords is None:
        missing.append("--save-cleartext-passwords")
    if not role:
        missing.append("--role")

    if missing:
        print(f"Error: Missing required configuration for context '{context_name}':", file=sys.stderr)
        print(f"  {', '.join(missing)}", file=sys.stderr)
        print(f"\nExample: agent.py check --context {context_name} {' '.join(f'{m} VALUE' for m in missing)}", file=sys.stderr)
        return 2

    # Save the context configuration
    config = ContextConfig(
        context_name=context_name,
        ssh_hostname=ssh_hostname,
        ssh_user=ssh_user,
        ssh_port=ssh_port,
        root_domain=root_domain,
        proxy_protocol=proxy_protocol,
        save_cleartext_passwords=save_cleartext_passwords,
        role=role,
    )
    save_context_config(config)

    # Run all checks
    report = run_all_checks(context_config=config)

    if args.json:
        print_json(report)
    else:
        print_report(report, full=args.full, use_pager=args.pager)

    return 0 if report.all_passed else 1


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="System state checker for d.rymcg.tech agent readiness",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command", metavar="COMMAND")

    # 'check' subcommand
    check_parser = subparsers.add_parser(
        "check", help="Run readiness checks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    check_parser.add_argument(
        "--json", action="store_true", help="Output in JSON format"
    )
    check_parser.add_argument(
        "--full", action="store_true", help="Show full checklist (default: only failures and next steps)"
    )
    check_parser.add_argument(
        "--pager", action="store_true", help="Enable pager for terminal output"
    )
    check_parser.add_argument(
        "--context", metavar="NAME", help="Set or switch to context NAME"
    )
    check_parser.add_argument(
        "--ssh-hostname", metavar="HOST", help="SSH hostname or IP address for the context"
    )
    check_parser.add_argument(
        "--ssh-user", metavar="USER", help="SSH username for the context"
    )
    check_parser.add_argument(
        "--ssh-port", type=int, metavar="PORT", help="SSH port for the context"
    )
    check_parser.add_argument(
        "--root-domain", metavar="DOMAIN", help="Root domain for the context (e.g., example.com)"
    )
    check_parser.add_argument(
        "--proxy-protocol", type=lambda x: x.lower() in ('true', '1', 'yes'),
        metavar="BOOL", help="Server is behind a proxy using proxy protocol (true/false)"
    )
    check_parser.add_argument(
        "--save-cleartext-passwords", type=lambda x: x.lower() in ('true', '1', 'yes'),
        metavar="BOOL", help="Save cleartext passwords in passwords.json (true/false)"
    )
    check_parser.add_argument(
        "--role", choices=VALID_ROLES,
        metavar="ROLE", help="Server role: 'public' (datacenter/open ports) or 'private' (NAT/no public ports)"
    )
    check_parser.set_defaults(func=cmd_check)

    # 'list' subcommand
    list_parser = subparsers.add_parser("list", help="List all configured contexts")
    list_parser.set_defaults(func=cmd_list)

    # 'current' subcommand
    current_parser = subparsers.add_parser("current", help="Show current context configuration")
    current_parser.set_defaults(func=cmd_current)

    # 'delete' subcommand
    delete_parser = subparsers.add_parser(
        "delete", help="Delete a context (Docker context, SSH config, saved config)"
    )
    delete_parser.add_argument("name", metavar="NAME", help="Name of the context to delete")
    delete_parser.set_defaults(func=cmd_delete)

    # 'clear' subcommand
    clear_parser = subparsers.add_parser(
        "clear", help="Delete all saved state and start fresh"
    )
    clear_parser.set_defaults(func=cmd_clear)

    args = parser.parse_args()

    try:
        # If no command given, print help
        if args.command is None:
            parser.print_help()
            return 0

        return args.func(args)

    except KeyboardInterrupt:
        print("\nInterrupted", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
