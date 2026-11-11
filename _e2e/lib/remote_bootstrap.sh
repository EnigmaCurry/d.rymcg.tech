#!/bin/bash
## remote_bootstrap.sh - Turn a fresh Debian droplet into a self-contained
## d.rymcg.tech "sworkstation": all workstation tooling installed on the
## droplet itself, with an SSH Docker context pointing back to localhost.
##
## This script is streamed to the droplet by _e2e/e2e.sh:
##
##   ssh root@IP "CONTEXT=... GIT_URL=... GIT_REF=... bash -s" < remote_bootstrap.sh
##
## It is adapted from _scripts/bootstrap_sworkstation.sh, with these differences:
##  * Fully idempotent: safe to re-run on an already-bootstrapped host.
##  * Clones from GIT_URL at GIT_REF (testing what a new user would get).
##  * Does NOT run the root `make config` wizard (the orchestrator does root
##    config non-interactively with config-dist + reconfigure; `YES=yes make
##    config` would silently enable proxy-protocol and cleartext passwords).
##  * Omits the bashrc stanza that forces the root user onto the default
##    context (this host's whole point is the ssh://localhost context).
##
## Environment variables:
##   CONTEXT = name of the Docker context to create (required)
##   GIT_URL = git remote to clone (default https://github.com/EnigmaCurry/d.rymcg.tech.git)
##   GIT_REF = branch, tag, or sha to check out (default master)

set -eo pipefail

CONTEXT="${CONTEXT:?CONTEXT is required (the Docker context name)}"
GIT_URL="${GIT_URL:-https://github.com/EnigmaCurry/d.rymcg.tech.git}"
GIT_REF="${GIT_REF:-master}"
REPO_DIR="${HOME}/git/vendor/enigmacurry/d.rymcg.tech"

if [ ! -f /etc/debian_version ]; then
    echo "ERROR: this bootstrap only supports Debian-based droplets." >&2
    exit 1
fi
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: this bootstrap must run as root." >&2
    exit 1
fi

echo "## [bootstrap] Installing workstation packages ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --assume-yes \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    bash build-essential gettext git openssl apache2-utils xdg-utils jq \
    sshfs wireguard curl inotify-tools w3m keychain age nano \
    openssh-server dnsutils ipcalc-ng

echo "## [bootstrap] Installing Docker (if missing) ..."
if ! command -v docker >/dev/null 2>&1; then
    curl -sSL https://get.docker.com | sh
fi
systemctl enable --now docker

echo "## [bootstrap] Installing uv (if missing) ..."
if ! command -v uv >/dev/null 2>&1 && [ ! -x "${HOME}/.local/bin/uv" ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="${PATH}:${HOME}/.local/bin"

echo "## [bootstrap] Cloning d.rymcg.tech from ${GIT_URL} (${GIT_REF}) ..."
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

echo "## [bootstrap] Configuring SSH to self (root@localhost) ..."
## OpenSSH 10 (Debian trixie) enables PerSourcePenalties by default: a source
## IP whose connections close without authenticating (e.g. ssh-keyscan probes)
## gets temporarily blocked. For a loopback self-ssh sworkstation - where root
## ssh's to 127.0.0.1 on every docker call - that is self-sabotage. Exempt the
## loopback from penalties (external sources keep the protection). Fall back to
## disabling penalties entirely if the exempt directive is unsupported, and
## restart sshd to clear any penalty already in effect from earlier probes:
_sshd_drop=/etc/ssh/sshd_config.d/99-e2e-loopback.conf
printf 'PerSourcePenaltyExemptList 127.0.0.1/32,::1/128\n' > "${_sshd_drop}"
if ! sshd -t 2>/dev/null; then
    printf 'PerSourcePenalties no\n' > "${_sshd_drop}"
    sshd -t 2>/dev/null || rm -f "${_sshd_drop}"
fi
systemctl enable ssh >/dev/null 2>&1 || true
systemctl restart ssh

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
if [ ! -f "${HOME}/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -N "" -f "${HOME}/.ssh/id_ed25519"
fi
touch "${HOME}/.ssh/authorized_keys"
chmod 600 "${HOME}/.ssh/authorized_keys"
if ! grep -qxF "$(cat "${HOME}/.ssh/id_ed25519.pub")" "${HOME}/.ssh/authorized_keys"; then
    cat "${HOME}/.ssh/id_ed25519.pub" >> "${HOME}/.ssh/authorized_keys"
fi
remove_ssh_host_entry() {
    local host_name="$1"
    if [[ -f ${HOME}/.ssh/config ]]; then
        sed -i "/^Host ${host_name}$/,/^Host /{ /^Host ${host_name}$/d; "'/^Host /!d }' "${HOME}/.ssh/config"
    fi
}
remove_ssh_host_entry "${CONTEXT}"
## Remove any stale multiplexing control sockets left by an earlier run (its
## orphaned master process is harmless once new connections stop using it):
rm -f "/tmp/ssh-$(id -un)-${USER:-root}@"*:22 2>/dev/null || true
touch "${HOME}/.ssh/config"
chmod 600 "${HOME}/.ssh/config"
## NOTE: no ControlMaster/ControlPersist for this self-context. Connection
## multiplexing only pays off by amortizing network latency to a remote host;
## for ssh to localhost it adds nothing and the shared master refuses
## concurrent sessions ("Session open refused by peer") when docker-over-ssh
## opens its dial-stdio channel. Plain per-connection ssh to localhost is
## instant and reliable.
## Use 127.0.0.1 (not "localhost"): on fresh cloud VMs the loopback SSH path
## can resolve to ::1 and get reset ("Connection closed by ::1 port 22"):
cat <<EOF >> "${HOME}/.ssh/config"
Host ${CONTEXT}
    User root
    Hostname 127.0.0.1
EOF
touch "${HOME}/.ssh/known_hosts"
## Refresh the host key ONCE (cloud-init may have regenerated it after an
## earlier run cached the old one). Avoid repeated keyscans: each is a no-auth
## connection that feeds PerSourcePenalties:
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
    echo "ERROR: could not ssh to self (${CONTEXT} -> 127.0.0.1) after retries." >&2
    ssh -n -o BatchMode=yes -o ConnectTimeout=5 "${CONTEXT}" true
fi
ssh -n -o BatchMode=yes "${CONTEXT}" whoami

echo "## [bootstrap] Creating Docker context '${CONTEXT}' (ssh://localhost) ..."
if ! docker context inspect "${CONTEXT}" >/dev/null 2>&1; then
    docker context create "${CONTEXT}" \
        --description "Created by d.rymcg.tech e2e bootstrap" \
        --docker "host=ssh://${CONTEXT}"
fi
docker context use "${CONTEXT}"
## Retry briefly: sshd/docker may need a moment to settle after enable:
for _try in 1 2 3 4 5; do
    if docker --context "${CONTEXT}" info -f '{{.ServerVersion}}' >/dev/null 2>&1; then
        break
    fi
    [ "${_try}" = "5" ] && docker --context "${CONTEXT}" info -f '{{.ServerVersion}}' >/dev/null
    sleep 3
done

echo "## [bootstrap] Installing bash shell integration ..."
mkdir -p "${HOME}/.config/d.rymcg.tech"
cat <<'EOF' > "${HOME}/.config/d.rymcg.tech/bashrc"
## d.rymcg.tech cli tool:
export EDITOR=${EDITOR:-nano}
export PATH=${PATH}:${HOME}/.local/bin:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"
__d.rymcg.tech_cli_alias d
## Add d.rymcg.tech alias for each Docker context:
EOF
cat <<EOF >> "${HOME}/.config/d.rymcg.tech/bashrc"
__d.rymcg.tech_context_alias ${CONTEXT} ${CONTEXT}
EOF
if ! grep -qF 'source ~/.config/d.rymcg.tech/bashrc' "${HOME}/.bashrc"; then
    cat <<EOF >> "${HOME}/.bashrc"

## d.rymcg.tech
source ~/.config/d.rymcg.tech/bashrc
EOF
fi

echo "## [bootstrap] Installing script-wizard ..."
"${REPO_DIR}/_scripts/install_script-wizard" --yes

echo "## [bootstrap] Done. Context '${CONTEXT}' is ready."
