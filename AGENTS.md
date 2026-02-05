# AGENTS.md

This file provides guidance for AI agents (Claude Code, etc.) working with d.rymcg.tech.

## Overview

d.rymcg.tech is a collection of Docker Compose projects and CLI tools
for managing remote Docker services from a local workstation. All
administration happens on the workstation; the server only runs
containers.

## First Steps: Check for Existing Configuration

Before asking the user for information, check if a context is already configured:

```bash
# Check if there's already a current context configured:
_scripts/agent.py current
```

If this returns JSON with all fields populated, you can skip asking the user and proceed directly to running the readiness checker.

If there's no current context or it returns an error, you must collect the following information from the user:

| Field                      | Description                                                 | Example         | Recommended Default |
|----------------------------|-------------------------------------------------------------|-----------------|---------------------|
| `context_name`             | Short nickname for the server (also used as SSH host alias) | `docker-server` | *(user must provide)* |
| `ssh_hostname`             | IP address or domain name of the Docker server              | `192.168.1.100` | *(user must provide)* |
| `ssh_user`                 | SSH username with Docker access on the server               | `root`          | `root` |
| `ssh_port`                 | SSH port on the server                                      | `22`            | `22` |
| `root_domain`              | Root domain for services on this server                     | `example.com`   | *(user must provide)* |
| `proxy_protocol`           | Is server behind a proxy using proxy protocol? (true/false) | `false`         | `false` |
| `save_cleartext_passwords` | Save cleartext passwords in passwords.json? (true/false)    | `false`         | `false` |

**Important:** All seven fields are required on first run. When presenting options to the user, offer the recommended defaults as the primary choice where applicable.

## Running the Agent Readiness Checker

Once you have gathered the information, run the readiness checker:

```bash
# First run - provide all required configuration:
_scripts/agent.py check \
  --context docker-server \
  --ssh-hostname 192.168.1.100 \
  --ssh-user root \
  --ssh-port 22 \
  --root-domain example.com \
  --proxy-protocol false \
  --save-cleartext-passwords false
```

More options:

```bash
# Subsequent runs - uses saved configuration:
_scripts/agent.py check

# Show help:
_scripts/agent.py

# Switch to a different context:
_scripts/agent.py check --context other-server

# Show current context configuration:
_scripts/agent.py current

# List all configured contexts:
_scripts/agent.py list

# Delete a specific context (Docker context, SSH config, saved config):
_scripts/agent.py delete myserver

# Reset all saved state (start fresh):
_scripts/agent.py clear
```

The configuration is saved to `~/.local/d.rymcg.tech/agent.contexts.json` and persists across runs.

## Agent Script Commands and Options

```
COMMANDS
    check               Run readiness checks
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
    --json               Output in JSON format (default: plain text)
    --full               Show full checklist (default: only failures and next steps)
    --pager              Enable pager for terminal output
```

## What the Readiness Checker Validates

The script checks prerequisites in order, with cascading dependencies:

1. **Workstation packages** - Required CLI tools (bash, make, git, docker, etc.)
2. **d.rymcg.tech setup**:
   - Repository cloned to expected path
   - `d.rymcg.tech` command in PATH
   - `script-wizard` tool installed
   - Root `.env_{CONTEXT}` file configured (with ROOT_DOMAIN, proxy settings, etc.)
3. **SSH configuration** - SSH key available (agent loaded or passwordless key)
4. **SSH host configured** - The context's SSH host entry exists in `~/.ssh/config`
5. **Docker context** - Docker context exists for the server
6. **Docker context reachable** - Can connect to Docker daemon via SSH
7. **Server readiness** - Traefik and acme-dns installed and healthy

Each step provides actionable next steps if it fails. Follow them in
order. Once you have finished a task, re-run the agent script again to
get the instructions for the next task. Repeat until all checks passed
and the script completes with return code 0.

## Exit Codes

- `0` - All checks passed, system is ready
- `1` - One or more checks failed, see next steps in output
- `2` - Script error or missing configuration

## Example Workflow

0. **Get the current config, if any**: Run
    ```bash
    _scripts/agent.py current
    ```
1. **Ask the user** for the seven required fields if they are missing from the current config.
   When presenting options, use the recommended defaults as the primary choice:
   - `context_name` - user must provide (short nickname for the server)
   - `ssh_hostname` - user must provide (IP or domain of Docker server)
   - `ssh_user` - recommend `root` as default
   - `ssh_port` - recommend `22` as default
   - `root_domain` - user must provide (e.g., example.com)
   - `proxy_protocol` - recommend `false` as default (most servers are not behind a proxy)
   - `save_cleartext_passwords` - recommend `false` as default (more secure)

2. **Run the agent script** with all parameters:
   ```bash
   _scripts/agent.py check --context myserver \
     --ssh-hostname 10.0.0.5 \
     --ssh-user admin \
     --ssh-port 22 \
     --root-domain mysite.com \
     --proxy-protocol false \
     --save-cleartext-passwords false
   ```

3. **Follow the next steps** in the output. The script will automatically
   configure SSH and Docker contexts as needed.

4. **Re-run the script** after completing each step until all checks pass.

## Key Commands (After Setup)

TODO: make this machine runnable.

### Context management (interactive)
```bash
d.rymcg.tech context              # Switch Docker context (which server to control)
d.rymcg.tech agent                # Run readiness checker with pager
```

### Per-project commands (run from any directory)
```bash
d.rymcg.tech make <project> config     # Configure .env file via wizard
d.rymcg.tech make <project> install    # Deploy to server
d.rymcg.tech make <project> reinstall  # Tear down and reinstall
d.rymcg.tech make <project> uninstall  # Remove containers, keep volumes
d.rymcg.tech make <project> destroy    # Remove containers AND volumes
d.rymcg.tech make <project> open       # Open in browser
d.rymcg.tech make <project> logs       # View logs
d.rymcg.tech make <project> status     # Check container status
```

## Initial Service Setup Order

After the readiness checker passes, install services in this order:

1. **traefik** - Reverse proxy with TLS termination
2. **whoami** - Test service to verify TLS is working
3. **forgejo** - Git host + OAuth2 identity provider (optional)
4. **traefik-forward-auth** - OAuth2 authentication middleware (optional)

## Further Documentation

- [README.md](README.md) - Full project overview and service list
- [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Linux workstation setup
- [DOCKER.md](DOCKER.md) - Docker server setup
- [TOUR.md](TOUR.md) - Guided tour of initial service installation
