# d.rymcg.tech workstation container

This describes an OCI container image that lets you manage remote
Docker servers with
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) without
installing anything on your workstation beyond bash, Podman, and this
image.
All configuration is SOPS-encrypted per server context, and every
workstation session runs in an ephemeral container — nothing is stored on the host
except your encrypted config and AGE key. The same image works for
headless CI/CD pipelines too. Build from source with the `drt` shell
function, or pull a pre-built image from the
[GitHub Container Registry](#pulling-the-image).

## Quick start

Install bash and [Podman](https://podman.io/docs/installation) on
your workstation. Your personal shell can be bash or zsh:

Add this to your RC file (`~/.bashrc`, `~/.bash_profile`, or
`~/.zshrc`):

```bash
## drt - d.rymcg.tech container image bootstrap
## Modify these vars as you wish:
: "${DRT_GIT_REPO:=https://github.com/EnigmaCurry/d.rymcg.tech.git}"
: "${DRT_BUILD_BRANCH:=master}"
: "${DRT_IMAGE:=localhost/d-rymcg-tech:latest}"
## Uncomment to install extra CLI tools and/or add container capabilities:
#: "${DRT_INSTALL_EXTRAS:=doctl,aws,gh,rclone,mc,step,wireguard}"
#: "${DRT_CAP_ADD:=NET_ADMIN}"

if podman image exists "${DRT_IMAGE}" 2>/dev/null; then
  source <(podman run --rm --pull=never --net=none --entrypoint cat \
    "${DRT_IMAGE}" \
    /home/user/git/vendor/enigmacurry/d.rymcg.tech/_container/drt.bashrc)
else
  drt() {
    echo "## First run: building ${DRT_IMAGE} ..." >&2
    local git_sha
    git_sha=$(git ls-remote "${DRT_GIT_REPO}" "refs/heads/${DRT_BUILD_BRANCH}" | cut -c1-12)
    podman build \
      --build-arg BRANCH="${DRT_BUILD_BRANCH}" \
      --build-arg GIT_REPO="${DRT_GIT_REPO}" \
      --build-arg GIT_SHA="${git_sha:-unknown}" \
      --build-arg INSTALL_EXTRAS="${DRT_INSTALL_EXTRAS:-}" \
      -t "${DRT_IMAGE}" -f _container/Dockerfile \
      "${DRT_GIT_REPO}#${DRT_BUILD_BRANCH}" \
    && echo >&2 \
    && echo "## Restart your shell to load drt." >&2 \
    && echo >&2
  }
fi
```

The first time you run `drt`, it builds the image from source.
Restart your shell afterwards to load the full function with tab
completion:

```bash
drt                  # builds the image on first run
exec bash            # restart shell to load full function
drt --init myserver  # bootstrap a new deployment context
drt myserver         # launch the interactive container
```

### Using a pre-built image

If you prefer to pull a pre-built image from the registry instead of
building from source:

```bash
podman pull ghcr.io/enigmacurry/d-rymcg-tech:latest
alias drt='bash <(podman run --rm --pull=never --net=none ghcr.io/enigmacurry/d-rymcg-tech drt)'
```

### Other options

Use `--image` to specify a custom image tag:

```bash
drt --image ghcr.io/enigmacurry/d-rymcg-tech:latest --init myserver
```

Extract `drt` to a local file:

```bash
podman run --rm --pull=never --net=none localhost/d-rymcg-tech:latest drt --extract > drt && chmod +x drt
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

The entire container state is derived from the encrypted SOPS config
file. Each session starts fresh — the entrypoint decrypts the config
and reconstructs the full working environment:

1. **Generate SSH keypair** — ephemeral ed25519 key created at startup,
   named after the context (e.g. `/run/secrets/ssh/myserver`)
2. **OpenBao authentication** (optional) — AppRole login, retrieves an
   AGE decryption key, signs the SSH key to get a short-lived
   certificate
3. **SOPS decryption** (optional) — decrypts an encrypted env file and
   exports the variables
4. **Docker context setup** — writes SSH config and creates a Docker
   context pointing at the remote host
5. **restore-env** — distributes env vars into each project's `.env`
   file, restores SSH keys, SSH config, known_hosts, doctl config,
   and passwords.json from the SOPS config
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
| `SSH_KEY_SCAN` | (auto) | Disabled for interactive sessions; set to `false` to skip in CI too |
| `BAO_CACERT` | | CA cert for OpenBao TLS (file path, PEM, or base64) |
| `BAO_CLIENT_CERT` | | mTLS client cert (file path, PEM, or base64) |
| `BAO_CLIENT_KEY` | | mTLS client key (file path, PEM, or base64) |
| `BAO_NAMESPACE` | | OpenBao namespace |
| `BAO_AUTH_PATH` | `auth/approle` | AppRole mount path |
| `BAO_SSH_MOUNT` | `ssh-client-signer` | SSH secrets engine mount |
| `BAO_SSH_ROLE` | `woodpecker-short-lived` | SSH signing role |
| `BAO_KV_MOUNT` | `secret` | KV secrets engine mount |
| `PROJECTS` | | Comma-separated list of projects to pre-create env files for |

## Usage examples (pure docker)

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

## Building from source

The `drt` shell function in [Quick start](#quick-start) automatically
builds the image on first run. No manual build step is needed.

### Upgrading

Rebuild the image with the latest changes:

```bash
drt --build
```

This clones the branch configured in the `drt` shell function (or
from the image label if using the simple alias), rebuilds, and re-tags
the image in place.

To permanently switch branches, update `DRT_BUILD_BRANCH` in your
`drt()` function in `~/.bashrc` or `~/.zshrc`, then run `drt --build`.

## Building from a local checkout

You can also build the image from a local clone of the repository:

```bash
d container-build                                              # Podman, tagged localhost/d-rymcg-tech:latest
d container-build --docker                                     # Docker
d container-build --image ghcr.io/you/d-rymcg-tech:v1           # Custom tag
d container-build --arch linux/amd64 --arch linux/arm64        # Multi-arch (uses buildx)
d container-build --image ghcr.io/you/d-rymcg-tech:v1 --push    # Build and push
```

## Getting started

First set up the `drt` alias as described in [Quick start](#quick-start).

Bootstrap a new deployment config with `drt --init` — this generates
an AGE encryption key (if you don't have one) and creates a
SOPS-encrypted config file:

```bash
drt --init myserver      # generates AGE key + creates ~/.config/d.rymcg.tech/config/myserver.sops.env
drt myserver             # launches interactive container
drt                      # interactive context chooser
drt --edit myserver      # decrypt, edit, and re-encrypt SOPS config
drt --view myserver      # decrypt and display SOPS config
```

Re-run `drt --init myserver` at any time to reconfigure SSH or
OpenBao settings — existing project configuration is preserved.

The only host dependency is Podman (or Docker with `--docker`). All
crypto tools (age, sops) run inside the container image.

## Interactive local usage

For local interactive workflows, use `drt` to launch the container
with a SOPS-encrypted config file:

```bash
drt myserver
```

This mounts your SOPS config read-write, forwards your SSH agent, and
provides your AGE key for decryption. The container restores all state
from the encrypted config: project `.env` files, SSH keys and config,
known_hosts, doctl config, and passwords.json.

On shell exit, you'll see a diff of any configuration changes and be
prompted to save them back to the encrypted file (default: yes). Only
changed values are re-encrypted, so git diffs on the SOPS file reflect
actual changes rather than full re-encryption noise.

Run `drt --help` for all options.

## Storing configs in git

You can track your `~/.config/d.rymcg.tech` directory in a private
git repository. The SOPS-encrypted config files are safe to commit
(they are encrypted with your AGE key), but the AGE keys themselves
are excluded by `.gitignore` and must be backed up separately.

### Initialize the config repo

```bash
drt --git-init
```

This interactively prompts for branch name (default: `master`), git
email, name, and remote URL, then initializes the repo, commits, and
pushes.

Once a remote is configured, `drt` will automatically:

- **Pull** (fast-forward only) before any operation (`--init`,
  `--edit`, `--view`, interactive session)
- **Commit** after any change (`--init`, `--edit`, `--clean`,
  interactive session exit)
- **Prompt to push** after each commit (default: yes)

If the local and remote branches have diverged, `drt` will stop with
an error — resolve manually with `drt --git`.

### What is safe to commit

| Path | Committed | Notes |
|---|---|---|
| `config/*.sops.env` | Yes | Encrypted with AGE — safe in a private repo |
| `keys/` | No | Excluded by `.gitignore` — back up separately |
| `gumdrop-presets/` | No | Excluded by `.gitignore` — serialized in SOPS config |
| `.gitignore` | Yes | Created by `drt --init` |
| `net-mode` | No | Excluded by `.gitignore` (local cache) |

### Managing the repo directly

`drt --git` is a pass-through to `git -C ~/.config/d.rymcg.tech`:

```bash
drt --git log            # view commit history
drt --git diff           # see uncommitted changes
drt --git push           # push to remote
drt --git status         # check repo status
```

## FIDO2 hardware key support (EXPERIMENTAL)

During `drt --init`, you can choose to protect your AGE encryption key
with a FIDO2 hardware key (e.g. SoloKey, YubiKey) instead of a
passphrase. This uses the
[age-plugin-fido2-hmac](https://github.com/olastor/age-plugin-fido2-hmac)
plugin, which is compiled from source and included in the container
image.

### How it works

When you select "FIDO2 hardware key" during init:

1. `drt` scans `/dev/hidraw*` for devices with the FIDO2 usage page
2. You select your key from a list (via script-wizard)
3. The plugin generates an AGE identity bound to your hardware key
4. You can enroll multiple keys for redundancy (e.g. a primary and a backup)

The FIDO2 device is passed through to the container via `--device` at
runtime. Each SOPS decrypt operation requires a physical touch of the
key.

### Multiple keys for backup

During init, after enrolling the first key you are prompted to enroll
additional backup keys. All enrolled keys can decrypt the same config —
you only need one plugged in at any time.

### Device detection

On each `drt` launch, the script looks for a previously enrolled
device. If the `.fido2` device hint file is missing or no enrolled
device is found, it falls back to interactive device selection via
script-wizard.

### Requirements

- A FIDO2 key with hmac-secret extension support (SoloKey Solo 2,
  YubiKey 5+, etc.)
- Read access to `/dev/hidraw*` on the host (you may need to be in
  the `plugdev` group)

### Files

| Path | Description |
|---|---|
| `keys/sops/<context>.key` | AGE identity file (contains FIDO2 credential references) |
| `keys/sops/<context>.fido2` | Device HID_IDs for runtime detection (one per line, regenerated automatically if missing) |

The `.key` file is essential — it contains the FIDO2 credential
references that, together with the physical key, allow decryption.
The `.fido2` file is a convenience hint for device detection and can
be regenerated by plugging in your key and running `drt`.

## What's in the image

- **Base:** Alpine Linux
- **Tools:** bash, make, git, openssl, jq, curl, sops, age,
  age-plugin-fido2-hmac, docker-cli, docker-cli-compose,
  openssh-client, uv (Python), doctl (DigitalOcean), script-wizard
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
