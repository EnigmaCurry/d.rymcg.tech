#!/bin/bash
## remote_bootstrap.sh - Turn a fresh Debian droplet into a self-contained
## d.rymcg.tech "sworkstation". The workstation files (repo clone, ~/.config,
## ~/.ssh, docker CLI config) live under an unprivileged admin user; the
## Docker context ssh's to root@localhost (so host-side operations like
## `make traefik traefik-user` can create system users, and docker-over-ssh's
## `dial-stdio` runs as root on root's default unix-socket context).
##
## This script is streamed to the droplet by _e2e/e2e.sh and executed as the
## admin user. System changes go through passwordless sudo.
##
## It is adapted from _scripts/bootstrap_sworkstation.sh, with these differences:
##  * Runs unprivileged (admin + sudo) instead of as root.
##  * Fully idempotent: safe to re-run on an already-bootstrapped host.
##  * Clones from GIT_URL at GIT_REF (testing what a new user would get).
##  * Does NOT run the root `make config` wizard (the orchestrator does root
##    config non-interactively with config-dist + reconfigure).
##
## Environment variables:
##   CONTEXT          = name of the Docker context to create (required)
##   CONTEXT_SSH_USER = user the context ssh's to on localhost (default root)
##   GIT_URL          = git remote to clone (default upstream)
##   GIT_REF          = branch, tag, or sha to check out (default master)
##   WORKSTATION_ONLY = true to set up only the workstation CLI tooling: no
##                      docker server, no ssh self-context, no docker context
##                      (default false)

set -eo pipefail

CONTEXT="${CONTEXT:?CONTEXT is required (the Docker context name)}"
CONTEXT_SSH_USER="${CONTEXT_SSH_USER:-root}"
GIT_URL="${GIT_URL:-https://github.com/EnigmaCurry/d.rymcg.tech.git}"
GIT_REF="${GIT_REF:-master}"
WORKSTATION_ONLY="${WORKSTATION_ONLY:-false}"
REPO_DIR="${HOME}/git/vendor/enigmacurry/d.rymcg.tech"

if [ ! -f /etc/debian_version ]; then
    echo "ERROR: this bootstrap only supports Debian-based droplets." >&2
    exit 1
fi
## Run system commands via sudo unless we happen to already be root:
if [ "$(id -u)" = "0" ]; then
    SUDO=""
else
    SUDO="sudo"
    sudo -n true 2>/dev/null || { echo "ERROR: passwordless sudo is required for ${USER}." >&2; exit 1; }
fi

echo "## [bootstrap] Running as $(id -un) (sudo='${SUDO:-none}')"

echo "## [bootstrap] Installing workstation packages ..."
export DEBIAN_FRONTEND=noninteractive
${SUDO} apt-get update
${SUDO} apt-get install --assume-yes \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    bash build-essential gettext git openssl apache2-utils xdg-utils jq \
    sshfs wireguard curl inotify-tools w3m keychain age nano \
    openssh-server dnsutils ipcalc-ng

if [ "${WORKSTATION_ONLY}" = "true" ]; then
    echo "## [bootstrap] Workstation-only: expecting Docker CLI (no server). $(docker --version 2>/dev/null || echo 'docker CLI MISSING')"
else
    echo "## [bootstrap] Installing Docker server (if missing) ..."
    if ! command -v docker >/dev/null 2>&1; then
        curl -sSL https://get.docker.com | ${SUDO} sh
    fi
    ${SUDO} systemctl enable --now docker

    ## Docker's default address pools only hold ~30 networks, and each app
    ## gets its own; carve 172.16.0.0/12 into /24s instead (4096 networks).
    ## Also pin docker0's address ('bip') to the first /24 of the pool (where
    ## Docker puts it anyway): with both set, the sysbox installer (for the
    ## sysbox-systemd app) has no network change to make, so it installs
    ## without a Docker restart and without removing every container.
    ## Merge into any existing daemon.json; restart only on change:
    POOLS='[{"base":"172.16.0.0/12","size":24}]'
    BIP='172.16.0.1/24'
    CURRENT=$(${SUDO} cat /etc/docker/daemon.json 2>/dev/null || echo '{}')
    if [ "$(echo "${CURRENT}" | jq -c '."default-address-pools"')" != "${POOLS}" ] \
           || [ "$(echo "${CURRENT}" | jq -r '.bip // ""')" != "${BIP}" ]; then
        echo "## [bootstrap] Setting Docker default-address-pools to ${POOLS} and bip to ${BIP} ..."
        ## jq's default indented output is the layout sysbox's installer looks for:
        echo "${CURRENT}" | jq --argjson p "${POOLS}" --arg b "${BIP}" \
                               '."default-address-pools" = $p | .bip = $b' \
            | ${SUDO} install -D -m 0644 /dev/stdin /etc/docker/daemon.json
        ${SUDO} systemctl restart docker
    fi

    ## Droplets have no swap, and a full app suite outgrows RAM: once memory
    ## runs out the host thrashes (ssh and HTTPS time out). Add a swap file
    ## (2x RAM, at most 16G) if there is no swap yet:
    if [ -z "$(${SUDO} /usr/sbin/swapon --show --noheadings)" ]; then
        MEM_MB=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
        SWAP_MB=$(( MEM_MB * 2 > 16384 ? 16384 : MEM_MB * 2 ))
        echo "## [bootstrap] Adding a ${SWAP_MB}M swap file ..."
        ${SUDO} fallocate -l "${SWAP_MB}M" /swapfile
        ${SUDO} chmod 600 /swapfile
        ${SUDO} /usr/sbin/mkswap /swapfile >/dev/null
        ${SUDO} /usr/sbin/swapon /swapfile
        grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | ${SUDO} tee -a /etc/fstab >/dev/null
    fi
fi

echo "## [bootstrap] Installing uv (if missing) ..."
if ! command -v uv >/dev/null 2>&1 && [ ! -x "${HOME}/.local/bin/uv" ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="${PATH}:${HOME}/.local/bin"

echo "## [bootstrap] Cloning d.rymcg.tech from ${GIT_URL} (${GIT_REF}) ..."
mkdir -p "$(dirname "${REPO_DIR}")"
if [ ! -e "${REPO_DIR}" ]; then
    git clone "${GIT_URL}" "${REPO_DIR}"
fi
git -C "${REPO_DIR}" remote set-url origin "${GIT_URL}"
git -C "${REPO_DIR}" fetch --tags origin
if git -C "${REPO_DIR}" show-ref --verify --quiet "refs/remotes/origin/${GIT_REF}"; then
    ## Branch: (re-)create the local branch tracking the remote one, so
    ## re-runs pick up new commits:
    git -C "${REPO_DIR}" checkout -B "${GIT_REF}" "origin/${GIT_REF}"
else
    ## Tag or sha: detached checkout:
    git -C "${REPO_DIR}" checkout --detach "${GIT_REF}"
fi
echo "## [bootstrap] Checked out: $(git -C "${REPO_DIR}" log -1 --oneline)"

echo "## [bootstrap] Installing python deps ..."
make -C "${REPO_DIR}" python-deps

if [ "${WORKSTATION_ONLY}" = "true" ]; then
echo "## [bootstrap] Workstation-only: skipping ssh self-context and Docker context (no local server)."
else
echo "## [bootstrap] Configuring SSH to the ${CONTEXT_SSH_USER}@localhost context ..."
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
if [ ! -f "${HOME}/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -N "" -f "${HOME}/.ssh/id_ed25519"
fi
## Authorize this key for CONTEXT_SSH_USER so the Docker context can ssh in.
## When CONTEXT_SSH_USER is root (the default), this needs sudo:
PUBKEY=$(cat "${HOME}/.ssh/id_ed25519.pub")
if [ "${CONTEXT_SSH_USER}" = "$(id -un)" ]; then
    AUTH_DIR="${HOME}/.ssh"
    TEE="tee"
else
    AUTH_DIR="$(eval echo "~${CONTEXT_SSH_USER}")/.ssh"
    TEE="${SUDO} tee"
fi
${SUDO} mkdir -p "${AUTH_DIR}"
${SUDO} chmod 700 "${AUTH_DIR}"
if ! ${SUDO} grep -qxF "${PUBKEY}" "${AUTH_DIR}/authorized_keys" 2>/dev/null; then
    echo "${PUBKEY}" | ${TEE} -a "${AUTH_DIR}/authorized_keys" >/dev/null
fi
${SUDO} chmod 600 "${AUTH_DIR}/authorized_keys"
if [ "${CONTEXT_SSH_USER}" != "$(id -un)" ]; then
    ${SUDO} chown -R "${CONTEXT_SSH_USER}:${CONTEXT_SSH_USER}" "${AUTH_DIR}" 2>/dev/null || true
fi

remove_ssh_host_entry() {
    local host_name="$1"
    if [[ -f ${HOME}/.ssh/config ]]; then
        sed -i "/^Host ${host_name}$/,/^Host /{ /^Host ${host_name}$/d; "'/^Host /!d }' "${HOME}/.ssh/config"
    fi
}
remove_ssh_host_entry "${CONTEXT}"
touch "${HOME}/.ssh/config"
chmod 600 "${HOME}/.ssh/config"
## No ControlMaster for this self-context (multiplexing only amortizes network
## latency to a remote host; for localhost it adds nothing and its shared
## master refuses docker-over-ssh's dial-stdio channel). Use 127.0.0.1, not
## "localhost", so the loopback path never resolves to ::1 and gets reset:
cat <<EOF >> "${HOME}/.ssh/config"
Host ${CONTEXT}
    User ${CONTEXT_SSH_USER}
    Hostname 127.0.0.1
EOF
touch "${HOME}/.ssh/known_hosts"
## Refresh the host key ONCE (cloud-init may have regenerated it):
ssh-keygen -R 127.0.0.1 -f "${HOME}/.ssh/known_hosts" >/dev/null 2>&1 || true
ssh-keyscan -H 127.0.0.1 >> "${HOME}/.ssh/known_hosts" 2>/dev/null || true
## Wait for sshd to accept key auth, then self-test. -n keeps ssh from reading
## this script off stdin:
_ssh_ok=false
for _try in $(seq 1 20); do
    if ssh -n -o BatchMode=yes -o ConnectTimeout=5 "${CONTEXT}" true 2>/dev/null; then
        _ssh_ok=true
        break
    fi
    sleep 3
done
if [ "${_ssh_ok}" != "true" ]; then
    echo "ERROR: could not ssh to ${CONTEXT_SSH_USER}@127.0.0.1 (context ${CONTEXT}) after retries." >&2
    ssh -n -o BatchMode=yes -o ConnectTimeout=5 "${CONTEXT}" true
fi
echo "## [bootstrap] ssh ${CONTEXT} -> $(ssh -n -o BatchMode=yes "${CONTEXT}" whoami)"

echo "## [bootstrap] Creating Docker context '${CONTEXT}' (ssh://${CONTEXT_SSH_USER}@localhost) ..."
if ! docker context inspect "${CONTEXT}" >/dev/null 2>&1; then
    docker context create "${CONTEXT}" \
        --description "Created by d.rymcg.tech e2e bootstrap" \
        --docker "host=ssh://${CONTEXT}"
fi
## Keep this user's ambient context on 'default' (admin's local unix socket).
## The orchestrator and the 'd' CLI select the e2e context explicitly via
## DOCKER_CONTEXT per command. dial-stdio runs on the remote as
## CONTEXT_SSH_USER (root), whose own current context is the untouched
## 'default' unix socket - so there is no ssh recursion.
docker context use default >/dev/null 2>&1 || true
## Verify the context reaches the daemon over ssh. Bounded + verbose so a slow
## or wedged ssh/docker connection surfaces instead of hanging silently:
echo "## [bootstrap] Verifying Docker context '${CONTEXT}' over ssh ..."
_docker_ok=false
for _try in $(seq 1 10); do
    _ver=$(timeout 25 docker --context "${CONTEXT}" info -f '{{.ServerVersion}}' 2>/tmp/e2e-dockerinfo.err) || true
    if [ -n "${_ver}" ]; then
        echo "## [bootstrap] Docker reachable via ssh (server ${_ver})."
        _docker_ok=true
        break
    fi
    echo "## [bootstrap]   attempt ${_try}/10 failed: $(tail -n 1 /tmp/e2e-dockerinfo.err 2>/dev/null)"
    sleep 3
done
if [ "${_docker_ok}" != "true" ]; then
    echo "ERROR: Docker context '${CONTEXT}' could not reach the daemon over ssh." >&2
    cat /tmp/e2e-dockerinfo.err >&2 || true
    exit 1
fi
fi  ## end: not WORKSTATION_ONLY

echo "## [bootstrap] Installing bash shell integration ..."
mkdir -p "${HOME}/.config/d.rymcg.tech"
cat <<'EOF' > "${HOME}/.config/d.rymcg.tech/bashrc"
## d.rymcg.tech cli tool:
export EDITOR=${EDITOR:-nano}
export PATH=${PATH}:${HOME}/.local/bin:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"
__d.rymcg.tech_cli_alias d
## NOTE: deliberately NOT exporting DOCKER_CONTEXT here. bash sources this
## (via ~/.bashrc) even for non-interactive ssh commands - including the
## fresh bash that make's $(shell docker_context) spawns - so exporting
## DOCKER_CONTEXT here would override the e2e context the orchestrator sets
## per command and make every project Makefile include the wrong .env file.
## Add d.rymcg.tech alias for each Docker context:
EOF
if [ "${WORKSTATION_ONLY}" != "true" ]; then
    cat <<EOF >> "${HOME}/.config/d.rymcg.tech/bashrc"
__d.rymcg.tech_context_alias ${CONTEXT} ${CONTEXT}
EOF
fi
if ! grep -qF 'source ~/.config/d.rymcg.tech/bashrc' "${HOME}/.bashrc"; then
    cat <<EOF >> "${HOME}/.bashrc"

## d.rymcg.tech
source ~/.config/d.rymcg.tech/bashrc
EOF
fi

echo "## [bootstrap] Installing script-wizard ..."
"${REPO_DIR}/_scripts/install_script-wizard" --yes

if [ "${WORKSTATION_ONLY}" = "true" ]; then
    echo "## [bootstrap] Done. Workstation CLI tooling is ready (no local Docker server / context)."
else
    echo "## [bootstrap] Done. Context '${CONTEXT}' (ssh://${CONTEXT_SSH_USER}@localhost) is ready."
fi
