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
_scripts/agent.py --current-context
```

If this returns JSON with all fields populated, you can skip asking the user and proceed directly to running the readiness checker.

If there's no current context or it returns an error, you must collect the following information from the user:

| Field          | Description                                                 | Example         |
|----------------|-------------------------------------------------------------|-----------------|
| `context_name` | Short nickname for the server (also used as SSH host alias) | `docker-server` |
| `ssh_hostname` | IP address or domain name of the Docker server              | `192.168.1.100` |
| `ssh_user`     | SSH username with Docker access on the server               | `root`          |
| `ssh_port`     | SSH port on the server                                      | `22`            |
| `root_domain`  | Root domain for services on this server                     | `example.com`   |

**Important:** All five fields are required. The agent script will fail if any are missing.

## Running the Agent Readiness Checker

Once you have gathered the information, run the readiness checker:

```bash
# First run - provide all required configuration:
_scripts/agent.py \
  --context docker-server \
  --ssh-hostname 192.168.1.100 \
  --ssh-user root \
  --ssh-port 22 \
  --root-domain example.com

# Subsequent runs - uses saved configuration:
_scripts/agent.py

# Switch to a different context:
_scripts/agent.py --context other-server

# List all configured contexts:
_scripts/agent.py --list-contexts
```

The configuration is saved to `~/.local/d.rymcg.tech/agent.contexts.json` and persists across runs.

## Agent Script Options

```
OPTIONS
    --context NAME      Set or switch to context NAME (required on first run)
    --ssh-hostname HOST SSH hostname or IP address
    --ssh-user USER     SSH username
    --ssh-port PORT     SSH port (default: 22)
    --root-domain DOMAIN Root domain (e.g., example.com)
    --list-contexts     List all configured contexts
    --json              Output in JSON format (default: plain text)
    --full              Show full checklist (default: only failures and next steps)
    --pager             Enable pager for terminal output
    --cached            Skip checks requiring SSH (use cached results if valid)
    --cache-ttl N       Cache time-to-live in seconds (default: 43200 / 12 hours)
```

## What the Readiness Checker Validates

The script checks prerequisites in order, with cascading dependencies:

1. **Workstation packages** - Required CLI tools (bash, make, git, docker, etc.)
2. **d.rymcg.tech setup** - Repository cloned, `d.rymcg.tech` in PATH
3. **SSH configuration** - SSH key available (agent loaded or passwordless key)
4. **SSH host configured** - The context's SSH host entry exists in `~/.ssh/config`
5. **Docker context** - Docker context exists for the server
6. **Docker context reachable** - Can connect to Docker daemon via SSH
7. **Server readiness** - Traefik and acme-dns installed and healthy

Each step provides actionable next steps if it fails. Follow them in order.

## Exit Codes

- `0` - All checks passed, system is ready
- `1` - One or more checks failed, see next steps in output
- `2` - Script error or missing configuration

## Example Workflow

1. **Ask the user** for the five required fields (context_name, ssh_hostname, ssh_user, ssh_port, root_domain)

2. **Run the agent script** with all parameters:
   ```bash
   _scripts/agent.py --context myserver --ssh-hostname 10.0.0.5 --ssh-user admin --ssh-port 22 --root-domain mysite.com
   ```

3. **Follow the next steps** in the output. The script will provide copy-pasteable bash commands.

4. **Re-run the script** after completing each step until all checks pass.

## Key Commands (After Setup)

### Context management
```bash
d context              # Switch Docker context (which server to control)
d.rymcg.tech agent     # Run readiness checker with pager
```

### Per-project commands (run from any directory)
```bash
d make <project> config     # Configure .env file via wizard
d make <project> install    # Deploy to server
d make <project> reinstall  # Tear down and reinstall
d make <project> uninstall  # Remove containers, keep volumes
d make <project> destroy    # Remove containers AND volumes
d make <project> open       # Open in browser
d make <project> logs       # View logs
d make <project> status     # Check container status
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
