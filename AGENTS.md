# AGENTS.md

This file provides guidance for AI agents (Claude Code, etc.) working with d.rymcg.tech.

## Overview

d.rymcg.tech is a collection of Docker Compose projects and CLI tools
for managing remote Docker services from a local workstation. All
administration happens on the workstation; the server only runs
containers.

## Prerequisites

### Clone the repository

The repository should be cloned to a conventional path:

```bash
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git ~/git/vendor/enigmacurry/d.rymcg.tech
```

### Install uv

The agent script (`_scripts/agent.py`) requires
[uv](https://docs.astral.sh/uv/) to run. Install it before running
any `_scripts/agent.py` commands:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

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
- `role` - user must provide (`public` or `private`)

If SSH config doesn't exist for this host, these will also be missing:
- `ssh_hostname` - user must provide
- `ssh_user` - recommend `root`
- `ssh_port` - recommend `22`

### Step 4: Ask only for missing fields

Only ask the user for the fields that couldn't be discovered. When presenting options, use these recommended defaults:

| Field                      | Description                                                           | Recommended Default   |
|----------------------------|-----------------------------------------------------------------------|-----------------------|
| `ssh_hostname`             | IP address or domain name of the Docker server                        | *(user must provide)* |
| `ssh_user`                 | SSH username with Docker access on the server                         | `root`                |
| `ssh_port`                 | SSH port on the server                                                | `22`                  |
| `root_domain`              | Root domain for services on this server                               | *(user must provide)* |
| `proxy_protocol`           | Is server behind a proxy using proxy protocol? (true/false)           | `false`               |
| `save_cleartext_passwords` | Save cleartext passwords in passwords.json? (true/false)              | `false`               |
| `role`                     | Server role: `public` (open ports) or `private` (NAT/no public ports) | *(user must provide)* |

### Step 5: Run check with missing values

Run check again, providing only the values that were missing:

```bash
# Example: if only root_domain, proxy_protocol, save_cleartext_passwords, and role were missing:
_scripts/agent.py check --context myserver \
  --root-domain example.com \
  --proxy-protocol false \
  --save-cleartext-passwords false \
  --role public
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
  --save-cleartext-passwords false \
  --role public

# If SSH config didn't exist, also provide:
_scripts/agent.py check --context docker-server \
  --ssh-hostname 192.168.1.100 \
  --ssh-user root \
  --ssh-port 22 \
  --root-domain example.com \
  --proxy-protocol false \
  --save-cleartext-passwords false \
  --role public
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
    --role ROLE          Server role: 'public' or 'private'
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
   Result: Shows missing fields. SSH config doesn't exist, so ssh_hostname, ssh_user, ssh_port are missing along with root_domain, proxy_protocol, save_cleartext_passwords, role.

4. **Ask user for missing fields** (with recommended defaults):
   - ssh_hostname: user provides `10.0.0.5`
   - ssh_user: offer `root` as default, user accepts
   - ssh_port: offer `22` as default, user accepts
   - root_domain: user provides `mysite.com`
   - proxy_protocol: offer `false` as default, user accepts
   - save_cleartext_passwords: offer `false` as default, user accepts
   - role: ask user if server is `public` or `private`

5. **Run check with all missing values**:
   ```bash
   _scripts/agent.py check --context myserver \
     --ssh-hostname 10.0.0.5 \
     --ssh-user root \
     --ssh-port 22 \
     --root-domain mysite.com \
     --proxy-protocol false \
     --save-cleartext-passwords false \
     --role public
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
   Result: Discovers ssh_hostname, ssh_user, ssh_port from `~/.ssh/config`. Only root_domain, proxy_protocol, save_cleartext_passwords, role are missing.

4. **Ask user for only the missing fields**:
   - root_domain: user provides `mysite.com`
   - proxy_protocol: offer `false` as default, user accepts
   - save_cleartext_passwords: offer `false` as default, user accepts
   - role: ask user if server is `public` or `private`

5. **Run check with only the missing values**:
   ```bash
   _scripts/agent.py check --context myserver \
     --root-domain mysite.com \
     --proxy-protocol false \
     --save-cleartext-passwords false \
     --role public
   ```

6. **Continue** until all checks pass.

## Key Commands (After Setup)

### Per-project commands (run from any directory)
```bash
# WARNING: This will OVERWRITE any existing .env file
d.rymcg.tech make <project> config-dist   # Create .env file from template (non-interactive)
# WARNING: This will OVERWRITE any existing .env file
d.rymcg.tech make <project> reconfigure var=KEY=VALUE  # Set a single env variable
d.rymcg.tech make <project> install       # Deploy to server
d.rymcg.tech make <project> reinstall     # Tear down and reinstall
d.rymcg.tech make <project> uninstall     # Remove containers, keep volumes
d.rymcg.tech make <project> destroy       # Remove containers AND volumes
d.rymcg.tech make <project> status        # Check container status
d.rymcg.tech make <project> logs-out      # View all logs (non-interactive)
d.rymcg.tech make <project> logs-out service=<name>  # View logs for one service
d.rymcg.tech make <project> restart service=<name>   # Restart one service
d.rymcg.tech make <project> open          # Open in browser
```

### Testing URLs with curl or wget

The root `.env_{CONTEXT}` file defines `PUBLIC_HTTPS_PORT` (defaults
to `443`). When testing service URLs with curl or wget, read this
port and include it in the URL:

```bash
# Read the configured HTTPS port:
PORT=$(d.rymcg.tech dotenv_get var=PUBLIC_HTTPS_PORT)

# Use it in curl/wget:
curl -sk "https://whoami.example.com:${PORT}"
wget -qO- --no-check-certificate "https://whoami.example.com:${PORT}"
```

If `PUBLIC_HTTPS_PORT` is `443`, the port can be omitted, but
always reading it first ensures correct behavior on non-standard
ports.

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
# WARNING: This will OVERWRITE any existing .env file. If you have customizations,
# back up your .env file first or use `reconfigure` to update only specific variables.
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

### Step 1: Determine server role

Before configuring services, ask the user about their server's
network exposure. This determines which TLS and acme-dns options are
available. Record the answer with the `--role` flag so the readiness
checker can adapt its behavior:

**`public`** - the server is in a datacenter or has open firewall
ports (80, 443, 53 reachable from the internet). The user may
optionally deploy their own acme-dns instance on this server.

```bash
_scripts/agent.py check --context myserver --role public
```

**`private`** - the server is behind NAT, on a private network, or
has no publicly open ports. The user must use acme-sh with an
*external* acme-dns server for DNS-01 challenges. Do not offer to
deploy acme-dns on this server.

```bash
_scripts/agent.py check --context myserver --role private
```

### Step 2: Configure Traefik

Traefik is the reverse proxy and must be installed first. The
`.env-dist` defaults are mostly sensible, but a few variables must be
set. Use the context name determined in Step 1 and the root domain
from the Progressive Discovery Workflow:

```bash
# Create env file from template:
# WARNING: This will OVERWRITE any existing .env file. If you have customizations,
# back up your .env file first or use `reconfigure` to update only specific variables.
d.rymcg.tech make traefik config-dist

# Create the traefik system user on the Docker host (sets UID/GID/DOCKER_GID):
traefik/setup.sh traefik_user

# Set the Docker context (must match the context name from Step 1):
d.rymcg.tech make traefik reconfigure var=DOCKER_CONTEXT={CONTEXT}

# Set the root domain (must match root_domain from discovery):
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ROOT_DOMAIN={ROOT_DOMAIN}
```

Ask the user which domain(s) need TLS certificates. The default is a
wildcard for the root domain (`*.{ROOT_DOMAIN}`). Set
`TRAEFIK_ACME_CERT_DOMAINS` as a JSON list where each entry is
`[CN, [SAN, ...]]`:

```bash
# Example: wildcard cert for *.example.com
d.rymcg.tech make traefik reconfigure var='TRAEFIK_ACME_CERT_DOMAINS=[["*.example.com",[]]]'
```

#### TLS configuration (acme-sh with acme-dns)

TLS certificates are obtained via the acme-sh sidecar container using
an acme-dns server for DNS-01 challenges. This supports wildcard
certificates and does not require port 443 to be publicly reachable.

#### Choosing an acme-dns server

Ask the user which acme-dns server to use. The available options
depend on the server role determined in Step 1:

| Option                     | Public server | Private server | Description                                                               |
|----------------------------|:-------------:|:--------------:|---------------------------------------------------------------------------|
| `https://auth.acme-dns.io` |      yes      |      yes       | Free public instance, no setup needed                                     |
| User-provided URL          |      yes      |      yes       | User has their own acme-dns deployed elsewhere                            |
| Deploy on this server      |      yes      |     **no**     | Self-host acme-dns here (see [below](#deploying-acme-dns-on-this-server)) |

For private servers, only offer the first two options.

#### Configure Traefik for acme-sh

```bash
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ENABLED=true
# For Let's Encrypt:
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_CA=acme-v02.api.letsencrypt.org
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_DIRECTORY=/directory
# Point to the chosen acme-dns server:
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_DNS_BASE_URL=https://auth.acme-dns.io
```

The `DOCKER_COMPOSE_PROFILES` must include `acme-sh`. The
`compose-profiles` target handles this automatically during
interactive config, but non-interactively you must set it:

```bash
d.rymcg.tech make traefik reconfigure var=DOCKER_COMPOSE_PROFILES=default,error_pages,acme-sh
```

#### Install Traefik

```bash
d.rymcg.tech make traefik install
```

If Traefik is already installed, use `reinstall` instead of `install`
to pick up profile changes:

```bash
d.rymcg.tech make traefik reinstall
```

#### Register acme-dns and create DNS records

After Traefik is installed (or reinstalled), register with acme-dns.
The output will show the CNAME records needed for each certificate
domain. **Show this output to the user** — they must create these DNS
records before certificates can be issued.

```bash
d.rymcg.tech make traefik acme-sh-register
```

After the user confirms the CNAME records are created, restart the
acme-sh container to trigger certificate issuance:

```bash
d.rymcg.tech make traefik restart service=acme-sh
```

Check logs to verify certificate issuance:

```bash
d.rymcg.tech make traefik logs-out service=acme-sh
```

### Deploying acme-dns on this server

This is **optional** and only available for **public servers**. It
deploys an acme-dns instance on the same Docker server as Traefik. The
server must have a public IP reachable on port 53 by the internet.

If the server is private, skip this section entirely and use
`https://auth.acme-dns.io` or another external acme-dns instance.

#### DNS delegation (do this first)

The user must configure their domain's DNS to delegate the `acme-dns`
subdomain before installing:

1. Add an **NS record**: `acme-dns.example.com` -> `auth.acme-dns.example.com`
2. Add an **A record**: `auth.acme-dns.example.com` -> `<public IP of server>`

#### Configure and install acme-dns

```bash
# Create env file from template:
# WARNING: This will OVERWRITE any existing .env file. If you have customizations,
# back up your .env file first or use `reconfigure` to update only specific variables.
d.rymcg.tech make acme-dns config-dist

# Set the subdomain (e.g., acme-dns.example.com):
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_SUBDOMAIN=acme-dns.example.com

# Set the listening IP (the server's network interface IP):
# Ask the user for this value.
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_LISTEN_IP_ADDRESS=10.0.0.5

# Set the public IP (how the CA server reaches this host):
# Often the same as listen IP, but may differ if behind a 1:1 NAT.
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_PUBLIC_IP_ADDRESS=10.0.0.5

# Optional: API port (default 2890 is usually fine):
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_API_PORT=2890

# Optional: SOA hostmaster email:
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_HOSTMASTER=hostmaster@example.com

# Install:
d.rymcg.tech make acme-dns install
```

Then set Traefik's `TRAEFIK_ACME_SH_ACME_DNS_BASE_URL` to
`https://acme-dns.example.com` and proceed with the register and cert
steps in the [acme-sh section](#register-acme-dns-and-create-dns-records)
above.

### Step 3: Install Forgejo (optional)

Forgejo is a self-hosted Git forge that also serves as the OAuth2
identity provider for traefik-forward-auth. Install it before
traefik-forward-auth if you plan to use OAuth2 authentication.

#### Configure Forgejo

```bash
# Create env file from template:
# WARNING: This will OVERWRITE any existing .env file. If you have customizations,
# back up your .env file first or use `reconfigure` to update only specific variables.
d.rymcg.tech make forgejo config-dist

# Set the external domain:
d.rymcg.tech make forgejo reconfigure var=FORGEJO_TRAEFIK_HOST=git.{ROOT_DOMAIN}

# Set instance name:
d.rymcg.tech make forgejo reconfigure var=FORGEJO_INSTANCE=default

# Set the display name (optional):
d.rymcg.tech make forgejo reconfigure var=APP_NAME="Forgejo"
```

Read `PUBLIC_HTTPS_PORT` from the root `.env_{CONTEXT}` file and
construct the ROOT_URL. If the port is `443`, omit it from the URL:

```bash
PORT=$(d.rymcg.tech dotenv_get var=PUBLIC_HTTPS_PORT)
if [ "${PORT}" = "443" ]; then
  ROOT_URL="https://git.{ROOT_DOMAIN}"
else
  ROOT_URL="https://git.{ROOT_DOMAIN}:${PORT}"
fi
d.rymcg.tech make forgejo reconfigure var=FORGEJO__server__ROOT_URL=${ROOT_URL}
```

Other useful defaults (already set in `.env-dist`, change if needed):

| Variable | Default | Description |
|----------|---------|-------------|
| `FORGEJO__service__DISABLE_REGISTRATION` | `true` | Disable public signup |
| `FORGEJO__service__REQUIRE_SIGNIN_VIEW` | `true` | Require login to browse |
| `FORGEJO__session__SESSION_LIFE_TIME` | `86400` | Session timeout (seconds) |
| `FORGEJO__mailer__ENABLED` | `false` | Enable email notifications |

#### Install Forgejo

```bash
d.rymcg.tech make forgejo install
```

#### Create the root administrator account

After install, the Forgejo setup wizard runs once at the web URL.
**The user must complete this step manually** — there is no
non-interactive way to create the first admin account via the wizard.

Tell the user to:

1. Open `https://git.{ROOT_DOMAIN}:{PORT}` in a browser
2. Complete the setup wizard (defaults are fine)
3. Register the admin account with username `root`

If the wizard was already completed and the user forgot the password:

```bash
d.rymcg.tech make forgejo shell
# Inside the container:
gitea admin user change-password --username root --password NEW_PASSWORD
```

After the wizard completes, run `reinstall` so the `.env` settings
take effect (the wizard writes its own `app.ini` which `reinstall`
overrides with the env vars):

```bash
d.rymcg.tech make forgejo reinstall
```

### Step 4: Install traefik-forward-auth (optional)

traefik-forward-auth adds OAuth2 authentication to any Traefik-routed
service. It requires an OAuth2 provider — typically the Forgejo
instance from Step 3.

#### Determine the OAuth2 provider URLs

The Auth URL is a browser redirect (user-facing) and uses the public
port. The Token URL and User URL are server-to-server calls made from
inside the container, which reaches Traefik via `host-gateway` on
port 443 — so these must **never** include the public port.

| URL | Template | Notes |
|-----|----------|-------|
| Auth URL | `https://git.{ROOT_DOMAIN}:{PORT}/login/oauth/authorize` | Browser redirect, uses public port |
| Token URL | `https://git.{ROOT_DOMAIN}/login/oauth/access_token` | Server-to-server, always port 443 |
| User URL | `https://git.{ROOT_DOMAIN}/api/v1/user` | Server-to-server, always port 443 |

The `docker-compose.yaml` maps the Forgejo domain to `host-gateway`
via `extra_hosts`, so the container can reach Traefik on port 443
even though the public-facing port may differ.

#### Create the OAuth2 application in Forgejo

**The user must do this manually.** Tell them to:

1. Log in to Forgejo as `root`
2. Go to **User Settings > Applications**
   (`https://git.{ROOT_DOMAIN}:{PORT}/user/settings/applications`)
3. Create a new OAuth2 application:
   - **Application Name**: `auth.{ROOT_DOMAIN}` (or any name)
   - **Redirect URL**: `https://auth.{ROOT_DOMAIN}:{PORT}/_oauth`
4. Copy the **Client ID** and **Client Secret**

Ask the user for these two values before proceeding.

#### Configure traefik-forward-auth

```bash
# Create env file from template:
# WARNING: This will OVERWRITE any existing .env file. If you have customizations,
# back up your .env file first or use `reconfigure` to update only specific variables.
d.rymcg.tech make traefik-forward-auth config-dist

# Auth host (the dedicated domain for the auth service):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_HOST=auth.{ROOT_DOMAIN}

# Cookie domain (root domain — covers all subdomains):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_COOKIE_DOMAIN={ROOT_DOMAIN}

# HTTPS port (must include the colon, e.g., `:8444` or `:443`):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_HTTPS_PORT=:{PORT}

# Generate and set a random secret:
SECRET=$(openssl rand -base64 45)
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_SECRET=${SECRET}

# Forgejo domain (without port):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_FORGEJO_DOMAIN=git.{ROOT_DOMAIN}

# OAuth provider URLs:
# Auth URL uses the public port (browser redirect):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_AUTH_URL=https://git.{ROOT_DOMAIN}:{PORT}/login/oauth/authorize
# Token and User URLs are server-to-server (always port 443, no public port):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_TOKEN_URL=https://git.{ROOT_DOMAIN}/login/oauth/access_token
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_USER_URL=https://git.{ROOT_DOMAIN}/api/v1/user

# Provider selection (use gitea/generic-oauth for Forgejo):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_SELECTED_PROVIDER=gitea
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_DEFAULT_PROVIDER=generic-oauth

# Logout redirect (back to Forgejo logout):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_LOGOUT_REDIRECT=https://git.{ROOT_DOMAIN}:{PORT}/logout

# OAuth2 credentials (from the Forgejo OAuth2 app):
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID={CLIENT_ID}
d.rymcg.tech make traefik-forward-auth reconfigure var=TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET={CLIENT_SECRET}
```

#### Install traefik-forward-auth

```bash
d.rymcg.tech make traefik-forward-auth install
```

#### Verify

```bash
d.rymcg.tech make traefik-forward-auth status

# Should return a 307 redirect to the Forgejo OAuth authorize URL:
curl -sk https://auth.{ROOT_DOMAIN}:{PORT}
```

### Step 5: Configure services to use OAuth2 (optional)

Once traefik-forward-auth is running, you can protect any
Traefik-routed service with OAuth2 login. This requires two things:

1. An **authorization group** in Traefik (a named list of allowed
   email addresses)
2. The service's **OAuth2 variables** set to enable the middleware

#### Create authorization groups

Authorization groups are stored in Traefik's
`TRAEFIK_HEADER_AUTHORIZATION_GROUPS` variable as a JSON map of group
names to lists of email addresses. The email addresses must match the
accounts on the OAuth2 provider (Forgejo).

```bash
# Set authorization groups (JSON map):
# Each group is a name → list of email addresses.
d.rymcg.tech make traefik reconfigure var='TRAEFIK_HEADER_AUTHORIZATION_GROUPS={"admin": ["root@localhost"], "users": ["root@localhost", "alice@example.com"]}'
```

After changing authorization groups, Traefik must be reinstalled to
pick up the new middleware configuration:

```bash
d.rymcg.tech make traefik reinstall
```

#### Enable OAuth2 on a service

Most services in d.rymcg.tech support OAuth2 via two environment
variables following the pattern `{PREFIX}_OAUTH2` and
`{PREFIX}_OAUTH2_AUTHORIZED_GROUP`. The prefix matches the service
name in uppercase.

**Example: protect whoami with OAuth2**

```bash
# Enable OAuth2:
d.rymcg.tech make whoami reconfigure var=WHOAMI_OAUTH2=true

# Set the authorization group (must exist in TRAEFIK_HEADER_AUTHORIZATION_GROUPS):
d.rymcg.tech make whoami reconfigure var=WHOAMI_OAUTH2_AUTHORIZED_GROUP=admin

# Reinstall to apply:
d.rymcg.tech make whoami reinstall
```

Now visiting the whoami URL will redirect to Forgejo for login. Only
users whose email is in the `admin` group will be granted access.

#### Check if a service supports OAuth2

Look for `OAUTH2` variables in the service's `.env-dist`:

```bash
grep OAUTH2 {PROJECT}/.env-dist
```

If the service has `{PREFIX}_OAUTH2` and
`{PREFIX}_OAUTH2_AUTHORIZED_GROUP` variables, it supports OAuth2.

#### Disable OAuth2 on a service

```bash
d.rymcg.tech make whoami reconfigure var=WHOAMI_OAUTH2=false
d.rymcg.tech make whoami reconfigure var=WHOAMI_OAUTH2_AUTHORIZED_GROUP=
d.rymcg.tech make whoami reinstall
```

## Further Documentation

- [README.md](README.md) - Full project overview and service list
- [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Linux workstation setup
- [DOCKER.md](DOCKER.md) - Docker server setup
- [TOUR.md](TOUR.md) - Guided tour of initial service installation
