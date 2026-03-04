# d-rymcg-tech container image

An Alpine-based Docker image that packages the entire d.rymcg.tech
framework for headless CI/CD deployments. The image connects to a
remote Docker host over SSH and runs `d make <project> install`
commands to deploy services.

## What's in the image

- **Base:** Alpine 3.21
- **System packages:** bash, make, git, openssl, jq, curl, sops, age,
  docker-cli, docker-cli-compose, openssh-client, and other shell
  utilities
- **uv:** Python package manager (installed via official install
  script), with a pre-seeded Python interpreter
- **script-wizard:** Interactive TUI helper (version pinned in
  `.tools.lock.json`)
- **d.rymcg.tech repo:** Full checkout baked into the image at
  `/home/user/git/vendor/enigmacurry/d.rymcg.tech`

The image runs as non-root user `user` (UID 1000).

## Building

From the d.rymcg.tech root directory:

```bash
# Via Makefile
cd _container && make build

# Or directly
docker build -f _container/Dockerfile -t d-rymcg-tech .
```

The build context must be the repository root (not `_container/`)
because the Dockerfile copies the entire repo into the image.

## Entrypoint

The entrypoint (`entrypoint.sh`) performs all setup before exec'ing
the provided command. It runs through these steps:

1. **Generate SSH keypair** — Creates an ephemeral ed25519 key in
   `/run/secrets/ssh/`
2. **OpenBao authentication** (if `BAO_ADDR` is set) — Logs in via
   AppRole, retrieves an AGE decryption key from KV, and signs the
   SSH public key to get a short-lived certificate
3. **SOPS decryption** (if `SOPS_CONFIG_FILE` is set) — Decrypts the
   encrypted env file and exports the variables (container env vars
   take precedence over SOPS values)
4. **Docker context setup** — Derives the context name from the SOPS
   filename, writes an SSH config with host keys and certificate, and
   creates/activates a Docker context pointing at the remote host
5. **restore-env** — Distributes the exported env vars into each
   project's `.env_<context>_default` file using `batch-reconfigure`
6. **Exec** — Hands off to the provided command (e.g., `d make
   traefik install`)

## Environment variables

### Required (minimum)

| Variable | Description |
|---|---|
| `DOCKER_CONTEXT` or `SSH_HOST` | Target server identifier (or use `SOPS_CONFIG_FILE`) |
| `SSH_HOST` | SSH hostname or IP of the remote Docker host |

### Required (with OpenBao)

| Variable | Description |
|---|---|
| `BAO_ADDR` | OpenBao server URL |
| `BAO_ROLE_ID` | AppRole role ID |
| `BAO_SECRET_ID` | AppRole secret ID |
| `BAO_AGE_KEY_PATH` | KV path to the AGE private key (e.g., `sops/d2-admin/myserver`) |

### Optional

| Variable | Default | Description |
|---|---|---|
| `SSH_USER` | `root` | SSH username |
| `SSH_PORT` | `22` | SSH port |
| `SSH_KEY_SCAN` | (enabled) | Set to `false` to skip ssh-keyscan |
| `SOPS_CONFIG_FILE` | | Path to SOPS-encrypted env file inside the container |
| `BAO_CACERT` | | CA certificate for OpenBao TLS (file path, PEM, or base64) |
| `BAO_CLIENT_CERT` | | mTLS client certificate (file path, PEM, or base64) |
| `BAO_CLIENT_KEY` | | mTLS client key (file path, PEM, or base64) |
| `BAO_NAMESPACE` | | OpenBao namespace |
| `BAO_AUTH_PATH` | `auth/approle` | AppRole mount path |
| `BAO_SSH_MOUNT` | `ssh-client-signer` | SSH secrets engine mount |
| `BAO_SSH_ROLE` | `woodpecker-short-lived` | SSH signing role |
| `BAO_KV_MOUNT` | `secret` | KV secrets engine mount |
| `PROJECTS` | | Comma-separated project list to ensure env files exist |

## Usage examples

### Local test (no OpenBao)

```bash
docker run --rm \
  -e DOCKER_CONTEXT=myserver \
  -e SSH_HOST=192.168.1.100 \
  -e SSH_KEY_SCAN=false \
  d-rymcg-tech \
  bash -c 'd make whoami install'
```

### CI pipeline (with OpenBao + SOPS)

The typical CI flow provides all `BAO_*` vars as secrets and a
`SOPS_CONFIG_FILE` pointing to the encrypted config checked into
the repo:

```bash
docker run --rm \
  -e BAO_ADDR=https://bao.example.com \
  -e BAO_ROLE_ID=... \
  -e BAO_SECRET_ID=... \
  -e BAO_AGE_KEY_PATH=sops/d2-admin/myserver \
  -e SOPS_CONFIG_FILE=config/myserver.sops.env \
  d-rymcg-tech \
  bash -c 'd make traefik install && d make whoami install'
```

## Setup scripts

### deploy-pipeline-build

Guided interactive walkthrough for setting up the build pipeline that
produces the `d-rymcg-tech` Docker image. Mirrors the d.rymcg.tech
GitHub repo to your Forgejo instance and configures Woodpecker CI to
automatically build and push the image to your registry.

```bash
d.rymcg.tech deploy-pipeline-build
```

This is a guidance-only tool — it prints step-by-step instructions
with personalized URLs but does not automate any actions. Use Enter
to advance, Backspace to go back.

### deploy-pipeline-template

Scaffolds a new deployment pipeline repo with Woodpecker CI
configuration, SOPS-encrypted config, and Jinja2 pipeline templates.

```bash
d.rymcg.tech deploy-pipeline-template
```

## Files

| File | Description |
|---|---|
| `Dockerfile` | Image definition (Alpine + system packages + uv + repo) |
| `entrypoint.sh` | Multi-step setup script (SSH, OpenBao, SOPS, Docker context) |
| `Makefile` | Convenience targets for building and testing locally |
| `deploy-pipeline-build.py` | Guided build pipeline setup (PEP 723, run via `uv`) |
| `deploy-pipeline-template.sh` | Deployment repo scaffolding script |
