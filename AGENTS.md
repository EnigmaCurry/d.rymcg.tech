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

If there's no current context or it returns an error, follow the **progressive discovery workflow** below.

## Progressive Discovery Workflow

The agent script can auto-discover some configuration from existing SSH config and Docker contexts. Follow these steps to minimize questions to the user:

### Step 1: Get the context name

If `current` returned no context, ask the user for **only the context name** first:

```bash
# What short nickname should we use for this server? (e.g., docker-server, prod, staging)
```

### Step 2: Run check to trigger discovery

Run the check command with just the context name to see what can be auto-discovered:

```bash
_scripts/agent.py check --context myserver
```

The script will:
- Look for an existing Docker context named `myserver`
- Parse `~/.ssh/config` for a host entry matching `myserver`
- Auto-discover `ssh_hostname`, `ssh_user`, and `ssh_port` if the SSH host exists
- Save any discovered values to the configuration

### Step 3: Check what's missing

The output will show which fields are still missing. Typically these cannot be auto-discovered:
- `root_domain` - user must provide
- `proxy_protocol` - user must provide (recommend `false`)
- `save_cleartext_passwords` - user must provide (recommend `false`)

If SSH config doesn't exist for this host, these will also be missing:
- `ssh_hostname` - user must provide
- `ssh_user` - recommend `root`
- `ssh_port` - recommend `22`

### Step 4: Ask only for missing fields

Only ask the user for the fields that couldn't be discovered. When presenting options, use these recommended defaults:

| Field                      | Description                                                 | Recommended Default   |
|----------------------------|-------------------------------------------------------------|-----------------------|
| `ssh_hostname`             | IP address or domain name of the Docker server              | *(user must provide)* |
| `ssh_user`                 | SSH username with Docker access on the server               | `root`                |
| `ssh_port`                 | SSH port on the server                                      | `22`                  |
| `root_domain`              | Root domain for services on this server                     | *(user must provide)* |
| `proxy_protocol`           | Is server behind a proxy using proxy protocol? (true/false) | `false`               |
| `save_cleartext_passwords` | Save cleartext passwords in passwords.json? (true/false)    | `false`               |

### Step 5: Run check with missing values

Run check again, providing only the values that were missing:

```bash
# Example: if only root_domain, proxy_protocol, and save_cleartext_passwords were missing:
_scripts/agent.py check --context myserver \
  --root-domain example.com \
  --proxy-protocol false \
  --save-cleartext-passwords false
```

## Running the Agent Readiness Checker

The readiness checker can be run incrementally - it saves discovered and provided values between runs:

```bash
# Initial run with just context name (triggers discovery):
_scripts/agent.py check --context docker-server

# Provide missing values (only what couldn't be discovered):
_scripts/agent.py check --context docker-server \
  --root-domain example.com \
  --proxy-protocol false \
  --save-cleartext-passwords false

# If SSH config didn't exist, also provide:
_scripts/agent.py check --context docker-server \
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

### Scenario A: No existing configuration

1. **Check for current context**:
   ```bash
   _scripts/agent.py current
   ```
   Result: Returns error or empty - no context configured.

2. **Ask the user for context name only**:
   > "What short nickname should we use for this server?"

   User provides: `myserver`

3. **Run check to trigger discovery**:
   ```bash
   _scripts/agent.py check --context myserver
   ```
   Result: Shows missing fields. SSH config doesn't exist, so ssh_hostname, ssh_user, ssh_port are missing along with root_domain, proxy_protocol, save_cleartext_passwords.

4. **Ask user for missing fields** (with recommended defaults):
   - ssh_hostname: user provides `10.0.0.5`
   - ssh_user: offer `root` as default, user accepts
   - ssh_port: offer `22` as default, user accepts
   - root_domain: user provides `mysite.com`
   - proxy_protocol: offer `false` as default, user accepts
   - save_cleartext_passwords: offer `false` as default, user accepts

5. **Run check with all missing values**:
   ```bash
   _scripts/agent.py check --context myserver \
     --ssh-hostname 10.0.0.5 \
     --ssh-user root \
     --ssh-port 22 \
     --root-domain mysite.com \
     --proxy-protocol false \
     --save-cleartext-passwords false
   ```

6. **Follow the next steps** in the output. The script will automatically
   configure SSH and Docker contexts as needed.

7. **Re-run the script** after completing each step until all checks pass.

### Scenario B: SSH config already exists

1. **Check for current context**:
   ```bash
   _scripts/agent.py current
   ```
   Result: Returns error or empty.

2. **Ask the user for context name**:
   User provides: `myserver`

3. **Run check to trigger discovery**:
   ```bash
   _scripts/agent.py check --context myserver
   ```
   Result: Discovers ssh_hostname, ssh_user, ssh_port from `~/.ssh/config`. Only root_domain, proxy_protocol, save_cleartext_passwords are missing.

4. **Ask user for only the missing fields**:
   - root_domain: user provides `mysite.com`
   - proxy_protocol: offer `false` as default, user accepts
   - save_cleartext_passwords: offer `false` as default, user accepts

5. **Run check with only the missing values**:
   ```bash
   _scripts/agent.py check --context myserver \
     --root-domain mysite.com \
     --proxy-protocol false \
     --save-cleartext-passwords false
   ```

6. **Continue** until all checks pass.

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

## Non-Interactive Service Configuration

The `make config` targets run interactive wizards that agents cannot
drive. Instead, agents should configure services non-interactively
using the `config-dist` and `reconfigure` make targets.

### General Pattern

```bash
# Step 1: Create .env file from template (copies .env-dist with all defaults)
d.rymcg.tech make <project> config-dist

# Step 2: Set individual variables
d.rymcg.tech make <project> reconfigure var=VAR_NAME=VALUE

# Step 3: Install the service
d.rymcg.tech make <project> install
```

The `reconfigure` target sets one variable at a time. Call it
repeatedly for each variable that needs to change from the default.
The `reconfigure` script will error if the variable name doesn't exist
in the .env file.

To read the current value of a variable:

```bash
d.rymcg.tech make <project> dotenv_get var=VAR_NAME
```

### Configuring Traefik

Traefik is the reverse proxy and must be installed first. The
`.env-dist` defaults are mostly sensible, but a few variables must be
set.

#### Required variables

```bash
# Create env file from template:
d.rymcg.tech make traefik config-dist

# Set the root domain (must match the context's ROOT_DOMAIN):
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ROOT_DOMAIN=example.com
```

#### TLS configuration

Choose ONE of these TLS methods:

**Option A: Builtin ACME (Let's Encrypt TLS-ALPN-01, simplest)**

Requires port 443 to be publicly reachable. No DNS configuration needed beyond A records.

```bash
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_ENABLED=true
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_CA_EMAIL=you@example.com
# Default challenge type is 'tls' (TLS-ALPN-01), which is correct for most setups
```

After installing Traefik with this option, use `make certs` to add certificate domains (this is interactive), or set `TRAEFIK_ACME_CERT_DOMAINS` directly:

```bash
# JSON list of domain objects, each with main and sans:
d.rymcg.tech make traefik reconfigure 'var=TRAEFIK_ACME_CERT_DOMAINS=[{"main":"example.com","sans":["*.example.com"]}]'
```

**Option B: acme-sh with acme-dns (wildcard certs via DNS-01)**

This uses the acme-sh sidecar container with an acme-dns server for DNS-01 challenges. Requires acme-dns to be installed first (see below).

```bash
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ENABLED=true
# For Let's Encrypt:
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_CA=acme-v02.api.letsencrypt.org
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_DIRECTORY=/directory
# Point to your acme-dns server:
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_DNS_BASE_URL=https://acme-dns.example.com
```

After enabling acme-sh, the `DOCKER_COMPOSE_PROFILES` must include
`acme-sh`. The `compose-profiles` target handles this automatically
during interactive config, but non-interactively you should set it:

```bash
d.rymcg.tech make traefik reconfigure var=DOCKER_COMPOSE_PROFILES=default,error_pages,acme-sh
```

**Option C: No TLS (not recommended for production)**

The defaults have all TLS methods disabled. If you skip TLS
configuration, Traefik will run without TLS termination.

#### Install Traefik

```bash
d.rymcg.tech make traefik install
```

### Configuring acme-dns

acme-dns is a minimal DNS server that handles ACME DNS-01 challenges.
It requires its own subdomain and DNS delegation.

#### Required variables

```bash
# Create env file from template:
d.rymcg.tech make acme-dns config-dist

# Set the subdomain (e.g., acme-dns.example.com):
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_SUBDOMAIN=acme-dns.example.com

# Set the listening IP (the server's network interface IP):
# Ask the user for this value - it's the IP where the server listens.
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_LISTEN_IP_ADDRESS=10.0.0.5

# Set the public IP (how the CA server reaches this host):
# Often the same as listen IP, but may differ behind NAT.
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_PUBLIC_IP_ADDRESS=10.0.0.5
```

#### Optional variables

```bash
# API port (default 2890 is usually fine):
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_API_PORT=2890

# SOA hostmaster email (optional):
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_HOSTMASTER=hostmaster@example.com
```

#### Install acme-dns

```bash
d.rymcg.tech make acme-dns install
```

#### DNS delegation required

After installing acme-dns, the user must configure their domain's DNS
to delegate the `acme-dns` subdomain:

1. Add an **NS record**: `acme-dns.example.com` -> `auth.acme-dns.example.com`
2. Add an **A record**: `auth.acme-dns.example.com` -> `<public IP of server>`

### Recommended Install Order for TLS with acme-dns

1. Install Traefik first (without TLS, or with builtin ACME):
   ```bash
   d.rymcg.tech make traefik config-dist
   d.rymcg.tech make traefik reconfigure var=TRAEFIK_ROOT_DOMAIN=example.com
   d.rymcg.tech make traefik install
   ```

2. Install acme-dns:
   ```bash
   d.rymcg.tech make acme-dns config-dist
   d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_SUBDOMAIN=acme-dns.example.com
   d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_LISTEN_IP_ADDRESS=10.0.0.5
   d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_PUBLIC_IP_ADDRESS=10.0.0.5
   d.rymcg.tech make acme-dns install
   ```

3. Ask user to set up DNS delegation for acme-dns subdomain.

4. Reconfigure Traefik to use acme-sh with acme-dns:
   ```bash
   d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ENABLED=true
   d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_CA=acme-v02.api.letsencrypt.org
   d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_DIRECTORY=/directory
   d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_DNS_BASE_URL=https://acme-dns.example.com
   d.rymcg.tech make traefik reconfigure var=DOCKER_COMPOSE_PROFILES=default,error_pages,acme-sh
   d.rymcg.tech make traefik reinstall
   ```

5. Register acme-dns account and create certificates:
   ```bash
   d.rymcg.tech make traefik acme-sh-register
   d.rymcg.tech make traefik acme-sh-cert
   ```

## Further Documentation

- [README.md](README.md) - Full project overview and service list
- [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Linux workstation setup
- [DOCKER.md](DOCKER.md) - Docker server setup
- [TOUR.md](TOUR.md) - Guided tour of initial service installation
