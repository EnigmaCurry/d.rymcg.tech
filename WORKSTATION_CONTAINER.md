# d-rymcg-tech container image

A pre-built Docker image that packages the entire
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) framework
for headless and interactive deployments to remote Docker hosts over SSH.

## Quick start (no repo needed)

Run `drt` directly from the container image — no git clone or file
extraction needed. Just define a shell alias:

```bash
## Add to your ~/.bashrc or ~/.zshrc:
alias drt='bash <(podman run --rm --pull=never ghcr.io/enigmacurry/d-rymcg-tech drt)'
```

Then bootstrap and launch:

```bash
## Bootstrap a new deployment context (generates AGE key + SOPS config):
drt --init myserver

## Launch the interactive container:
drt myserver
```

Use `--docker` instead of the default Podman engine:

```bash
alias drt='bash <(docker run --rm --pull=never ghcr.io/enigmacurry/d-rymcg-tech drt)'
drt --docker --init myserver
drt --docker myserver
```

Use `--image` to specify a custom image tag:

```bash
drt --image ghcr.io/enigmacurry/d-rymcg-tech:latest --init myserver
```

Alternatively, extract `drt` to a local file:

```bash
podman run --rm --pull=never ghcr.io/enigmacurry/d-rymcg-tech drt --extract > drt && chmod +x drt
./drt --help
```

Run `drt --help` for all options.

## Pulling the image

The image is published to GitHub Container Registry:

```bash
docker pull ghcr.io/enigmacurry/d-rymcg-tech:latest
```

Images are tagged with `latest` and with the short git SHA (e.g.
`ghcr.io/enigmacurry/d-rymcg-tech:73bb13f09636`). Both `linux/amd64`
and `linux/arm64` platforms are available.

If you host a Forgejo mirror with Woodpecker CI, the image can also be
built and pushed to your own registry. See
[_container/README.md](_container/README.md) for build instructions.

## How it works

The entrypoint handles all setup before executing your command:

1. **Generate SSH keypair** — ephemeral ed25519 key created at startup
2. **OpenBao authentication** (optional) — AppRole login, retrieves an
   AGE decryption key, signs the SSH key to get a short-lived
   certificate
3. **SOPS decryption** (optional) — decrypts an encrypted env file and
   exports the variables
4. **Docker context setup** — writes SSH config and creates a Docker
   context pointing at the remote host
5. **restore-env** — distributes env vars into each project's `.env`
   file
6. **Exec** — runs your command (e.g. `d make traefik install`)

## Environment variables

### Minimal setup (no secrets manager)

| Variable | Description |
|---|---|
| `SSH_HOST` | Hostname or IP of the remote Docker host |
| `SSH_USER` | SSH username (default: `root`) |
| `SSH_PORT` | SSH port (default: `22`) |
| `SSH_KEY` | SSH private key (file path, PEM, or base64). If unset, a key is generated |
| `SSH_KNOWN_HOSTS` | Known hosts content (file path, plain text, or base64) |
| `DOCKER_CONTEXT` | Docker context name (default: derived from `SSH_HOST` or `SOPS_CONFIG_FILE`) |

SSH credentials can be provided three ways: mount files as volumes,
set `SSH_KEY` and `SSH_KNOWN_HOSTS` env vars (supports file paths,
inline PEM/text, or base64-encoded values), or let OpenBao handle
everything.

### With OpenBao (recommended for CI)

| Variable | Description |
|---|---|
| `BAO_ADDR` | OpenBao server URL (e.g. `https://bao.example.com`) |
| `BAO_ROLE_ID` | AppRole role ID |
| `BAO_SECRET_ID` | AppRole secret ID |
| `BAO_AGE_KEY_PATH` | KV path to the AGE private key (e.g. `sops/my-deploy/myserver`) |
| `SOPS_CONFIG_FILE` | Path to SOPS-encrypted env file inside the container |

When `BAO_ADDR` is set, the entrypoint authenticates via AppRole,
retrieves the AGE key for SOPS decryption, and signs the SSH key to
get a short-lived certificate. All SSH and Docker context config is
derived automatically.

### Optional variables

| Variable | Default | Description |
|---|---|---|
| `SSH_KEY_SCAN` | (enabled) | Set to `false` to skip ssh-keyscan |
| `BAO_CACERT` | | CA cert for OpenBao TLS (file path, PEM, or base64) |
| `BAO_CLIENT_CERT` | | mTLS client cert (file path, PEM, or base64) |
| `BAO_CLIENT_KEY` | | mTLS client key (file path, PEM, or base64) |
| `BAO_NAMESPACE` | | OpenBao namespace |
| `BAO_AUTH_PATH` | `auth/approle` | AppRole mount path |
| `BAO_SSH_MOUNT` | `ssh-client-signer` | SSH secrets engine mount |
| `BAO_SSH_ROLE` | `woodpecker-short-lived` | SSH signing role |
| `BAO_KV_MOUNT` | `secret` | KV secrets engine mount |
| `PROJECTS` | | Comma-separated list of projects to pre-create env files for |

## Usage examples

### Interactive shell (volume mounts)

```bash
docker run --rm -it \
  -e SSH_HOST=192.168.1.100 \
  -e SSH_USER=root \
  -e SSH_KEY_SCAN=false \
  -v ~/.ssh/id_ed25519:/run/secrets/ssh/id_ed25519:ro \
  -v ~/.ssh/known_hosts:/run/secrets/ssh/known_hosts:ro \
  ghcr.io/enigmacurry/d-rymcg-tech
```

### Interactive shell (env vars)

```bash
docker run --rm -it \
  -e SSH_HOST=192.168.1.100 \
  -e SSH_USER=root \
  -e SSH_KEY_SCAN=false \
  -e SSH_KEY="$(base64 -w0 ~/.ssh/id_ed25519)" \
  -e SSH_KNOWN_HOSTS="$(base64 -w0 ~/.ssh/known_hosts)" \
  ghcr.io/enigmacurry/d-rymcg-tech
```

### Deploy a service

```bash
docker run --rm \
  -e SSH_HOST=192.168.1.100 \
  -e SSH_USER=root \
  -e SSH_KEY="$(base64 -w0 ~/.ssh/id_ed25519)" \
  -e SSH_KNOWN_HOSTS="$(base64 -w0 ~/.ssh/known_hosts)" \
  ghcr.io/enigmacurry/d-rymcg-tech \
  bash -c 'd make whoami config && d make whoami install'
```

### CI pipeline with OpenBao and SOPS

This is the typical Woodpecker CI / CI pipeline usage. All secrets
come from environment variables (set as CI secrets), and the encrypted
config file is checked into the deployment repo:

```bash
docker run --rm \
  -e BAO_ADDR=https://bao.example.com \
  -e BAO_ROLE_ID="$BAO_ROLE_ID" \
  -e BAO_SECRET_ID="$BAO_SECRET_ID" \
  -e BAO_AGE_KEY_PATH=sops/my-deploy/myserver \
  -e SOPS_CONFIG_FILE=config/myserver.sops.env \
  -v ./config:/home/user/git/vendor/enigmacurry/d.rymcg.tech/config:ro \
  ghcr.io/enigmacurry/d-rymcg-tech \
  bash -c 'd make traefik install && d make whoami install'
```

No SSH keys or known_hosts are needed — OpenBao issues a short-lived
SSH certificate and the entrypoint runs ssh-keyscan automatically.

## Building locally

You can build the image from your local checkout:

```bash
d container-build                                              # Podman, tagged localhost/d-rymcg-tech:latest
d container-build --docker                                     # Docker
d container-build --image ghcr.io/you/d-rymcg-tech:v1           # Custom tag
d container-build --arch linux/amd64 --arch linux/arm64        # Multi-arch (uses buildx)
d container-build --image ghcr.io/you/d-rymcg-tech:v1 --push    # Build and push
```

## Getting started

Bootstrap a new deployment config with a single command — this
generates an AGE encryption key (if you don't have one) and creates a
SOPS-encrypted config file:

```bash
d container-init myserver      # generates AGE key + creates ~/.config/d.rymcg.tech/config/myserver.sops.env
d container myserver           # launches interactive container
```

The only host dependency is Podman (or Docker with `--docker`). All
crypto tools (age, sops) run inside the container image.

## Interactive local usage

For local interactive workflows, use `d container` to launch the
container with a SOPS-encrypted config file:

```bash
d container config/myserver.sops.env
```

This mounts your SOPS config read-write, forwards your SSH agent, and
provides your AGE key for decryption. On shell exit, you'll see a diff
of any configuration changes and can save them back to the encrypted
file.

### Options

| Option | Description |
|---|---|
| `--image TAG` | Container image (default: `localhost/d-rymcg-tech:latest`) |
| `--docker` | Use Docker instead of Podman |
| `--age-key FILE` | AGE key file (default: `~/.config/sops/age/keys.txt`) |
| `--ssh-key FILE` | SSH key file (disables agent forwarding) |
| `--no-save` | Disable save-on-exit prompt |

### Examples

```bash
# Basic usage with default settings (Podman, SSH agent forwarding)
d container config/myserver.sops.env

# Use Docker instead of Podman
d container --docker config/myserver.sops.env

# Use a custom image
d container --image localhost/d-rymcg-tech:latest config/myserver.sops.env

# Mount an SSH key instead of forwarding the agent
d container --ssh-key ~/.ssh/id_ed25519 config/myserver.sops.env

# Skip the save-on-exit prompt
d container --no-save config/myserver.sops.env
```

## What's in the image

- **Base:** Alpine Linux
- **Tools:** bash, make, git, openssl, jq, curl, sops, age,
  docker-cli, docker-cli-compose, openssh-client, uv (Python),
  script-wizard
- **d.rymcg.tech:** full repo at
  `/home/user/git/vendor/enigmacurry/d.rymcg.tech`
- **User:** runs as `user` (UID 1000)

## Scaffolding a deployment repo

To create a new deployment repo with CI pipeline config and encrypted
environment files:

```bash
d.rymcg.tech deploy-pipeline-template
```

The wizard asks for your registry, repo owner, image source (ghcr.io
or Forgejo), and target server, then generates a ready-to-push repo
with Woodpecker CI configuration and SOPS-encrypted config templates.

See [AUTOMATION.md](AUTOMATION.md) for the full architecture overview.
