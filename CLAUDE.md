# CLAUDE.md

This file provides guidance to Claude Code when working with d.rymcg.tech.

## Overview

d.rymcg.tech is a collection of Docker Compose projects and CLI tools for managing remote Docker services from a local workstation. All administration happens on the workstation; the server only runs containers.

Key features:
- Traefik as front-door proxy with automatic TLS (Let's Encrypt or self-hosted Step-CA)
- Configuration via `.env_{CONTEXT}_{INSTANCE}` files per project/context/instance
- Each sub-project has a Makefile with standardized targets
- CLI tool (`d.rymcg.tech` or `d` alias) wraps all commands and works from any directory

## Installation (Linux Workstation)

### Install dependencies

Debian/Ubuntu:
```bash
sudo apt update
sudo apt install bash build-essential gettext git openssl apache2-utils \
                 xdg-utils jq sshfs wireguard curl inotify-tools w3m \
                 moreutils keychain ipcalc-ng
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://get.docker.com | sudo bash
```

Fedora:
```bash
sudo dnf install bash gettext openssl git xdg-utils jq sshfs curl inotify-tools \
                 httpd-tools make wireguard-tools w3m moreutils ipcalc uv
curl -fsSL https://get.docker.com | sudo bash
```

### Disable local Docker (workstation controls remote servers)
```bash
sudo systemctl disable --now docker.service docker.socket
```

### Clone repository
```bash
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ~/git/vendor/enigmacurry/d.rymcg.tech
```

### Configure Bash (~/.bashrc)
```bash
cat <<'EOF' >> ~/.bashrc
eval "$(keychain --quiet --eval --agents ssh id_ed25519)"
export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"
__d.rymcg.tech_cli_alias d
EOF
```

### Create SSH key
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
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

### Or use make directly (requires cd into project directory)
```bash
cd traefik && make config
```

## Initial Service Setup Order

1. **acme-dns** - DNS server for ACME challenges (TLS cert creation)
   ```bash
   d make acme-dns config
   d make acme-dns install
   ```

2. **traefik** - Reverse proxy with TLS termination
   ```bash
   d make traefik config   # Configure certificates, entrypoints
   d make traefik install
   ```

3. **whoami** - Test service to verify TLS is working
   ```bash
   d make whoami config
   d make whoami install
   d script tls_debug whoami.example.com   # Verify certificate
   ```

4. **forgejo** - Git host + OAuth2 identity provider
   ```bash
   d make forgejo config
   d make forgejo install
   d make forgejo open     # Create admin account, then reinstall
   ```

5. **traefik-forward-auth** - OAuth2 authentication middleware
   ```bash
   d make traefik-forward-auth config
   d make traefik-forward-auth install
   ```

6. **postfix-relay** - Email relay for other containers

7. **step-ca** - Self-hosted Certificate Authority (optional, replaces Let's Encrypt)

## DNS Requirements

For each deployed service:
- Create `A` record pointing domain to server IP
- For wildcard certs: Create `CNAME` record for `_acme-challenge.domain` pointing to acme-dns

## Project Structure

- Each service has its own subdirectory with `Makefile`, `docker-compose.yaml`, `README.md`
- `.env_{CONTEXT}_{INSTANCE}` files store per-deployment configuration
- `_scripts/` contains shared tooling
- Configuration is never stored on the server; only on workstation

## Common Services

Core infrastructure: traefik, acme-dns, forgejo, traefik-forward-auth, postfix-relay, step-ca

Applications: nextcloud, vaultwarden, immich, freshrss, ollama, open-webui, jupyterlab, minio, homepage, prometheus/grafana, and many more (see README.md for full list)

## Multiple Instances

Create multiple instances of the same service using instance names:
```bash
d make whoami --instance=dev config
d make whoami --instance=prod config
```

See INSTANCES.md for details.
