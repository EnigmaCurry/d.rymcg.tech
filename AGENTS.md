# AGENTS.md

This file provides guidance for AI agents (Claude Code, etc.) working with d.rymcg.tech.

## Overview

d.rymcg.tech is a collection of Docker Compose projects and CLI tools for managing remote Docker services from a local workstation. All administration happens on the workstation; the server only runs containers.

Key features:
- Traefik as front-door proxy with automatic TLS (Let's Encrypt or self-hosted Step-CA)
- Configuration via `.env_{CONTEXT}_{INSTANCE}` files per project/context/instance
- Each sub-project has a Makefile with standardized targets
- CLI tool (`d.rymcg.tech` or `d` alias) wraps all commands and works from any directory

## Agent Readiness Checker

Before working with d.rymcg.tech, run the readiness checker to verify the system is properly configured:

```bash
_scripts/agent.py
```

### What it checks

1. **Workstation packages** - All 17 required CLI tools (bash, make, git, docker, etc.)
2. **d.rymcg.tech setup** - Repository cloned, `d.rymcg.tech` in PATH, bash completion configured
3. **SSH configuration** - SSH key available (agent loaded or passwordless key)
4. **Docker context** - Remote context exists, is selected, and is reachable
5. **Server readiness** - Traefik and acme-dns installed and healthy

### Output modes

```bash
_scripts/agent.py          # Human-readable checklist with next steps
_scripts/agent.py --json   # JSON output for programmatic use
_scripts/agent.py --quiet  # Only show failures and next steps
```

### Exit codes

- `0` - All checks passed, system is ready
- `1` - One or more checks failed, see next steps
- `2` - Script error

### Example output

```
============================================================
d.rymcg.tech System Readiness Check
============================================================

## Workstation packages

  [x] Workstation packages
      All 17 required packages installed

## d.rymcg.tech setup

  [x] Repository cloned
      Found at /home/user/git/vendor/enigmacurry/d.rymcg.tech

  [x] d.rymcg.tech in PATH
      d.rymcg.tech command available

  [x] Bash completion configured
      Completion configured in .bashrc

## SSH configuration

  [x] SSH key available
      SSH agent has keys loaded

## Docker context

  [x] Remote Docker context exists
      Remote contexts: myserver

  [x] Current context is remote
      Current context: myserver

  [x] Docker context reachable
      Context 'myserver' is reachable

## Server readiness

  [x] Traefik installed and healthy
      Traefik status: Up 2 hours (healthy)

  [x] acme-dns installed and healthy
      acme-dns status: Up 2 hours (healthy)

Status: READY - All checks passed!
```

## Key Commands

### Context management
```bash
d context              # Switch Docker context (which server to control)
d aliases              # Show example Bash aliases for contexts
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
d make <project> readme     # Open project README
```

## Initial Service Setup Order

1. **acme-dns** - DNS server for ACME challenges (TLS cert creation)
2. **traefik** - Reverse proxy with TLS termination
3. **whoami** - Test service to verify TLS is working
4. **forgejo** - Git host + OAuth2 identity provider
5. **traefik-forward-auth** - OAuth2 authentication middleware
6. **postfix-relay** - Email relay for other containers
7. **step-ca** - Self-hosted Certificate Authority (optional)

## Project Structure

- Each service has its own subdirectory with `Makefile`, `docker-compose.yaml`, `README.md`
- `.env_{CONTEXT}_{INSTANCE}` files store per-deployment configuration
- `_scripts/` contains shared tooling including `agent.py`
- Configuration is never stored on the server; only on workstation

## Further Documentation

- [README.md](README.md) - Full project overview and service list
- [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Linux workstation setup
- [DOCKER.md](DOCKER.md) - Docker server setup
- [TOUR.md](TOUR.md) - Guided tour of initial service installation
