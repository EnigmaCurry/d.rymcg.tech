# d-rymcg-tech container image

A pre-built Docker image that packages the entire
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) framework
for headless deployments to remote Docker hosts over SSH.

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
| `DOCKER_CONTEXT` | Docker context name (default: derived from `SSH_HOST` or `SOPS_CONFIG_FILE`) |

With this mode you must mount your own SSH key and known_hosts into
the container or set `SSH_KEY_SCAN=false` to skip host key
verification.

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

### Interactive shell

```bash
docker run --rm -it \
  -e SSH_HOST=192.168.1.100 \
  -e SSH_USER=root \
  -e SSH_KEY_SCAN=false \
  -v ~/.ssh/id_ed25519:/run/secrets/ssh/id_ed25519:ro \
  -v ~/.ssh/known_hosts:/run/secrets/ssh/known_hosts:ro \
  ghcr.io/enigmacurry/d-rymcg-tech
```

This drops you into a bash shell with the `d` CLI available and a
Docker context configured for your remote host.

### Deploy a service

```bash
docker run --rm \
  -e SSH_HOST=192.168.1.100 \
  -e SSH_USER=root \
  -e SSH_KEY_SCAN=false \
  -v ~/.ssh/id_ed25519:/run/secrets/ssh/id_ed25519:ro \
  -v ~/.ssh/known_hosts:/run/secrets/ssh/known_hosts:ro \
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
