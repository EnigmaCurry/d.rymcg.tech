#!/bin/bash
## Quick setup of a d.rymcg.tech Sworkstation in a fresh debian VM:
## ALIAS=l ROOT_DOMAIN=d.example.com bash <(curl https://raw.githubusercontent.com/EnigmaCurry/d.rymcg.tech/refs/heads/master/_scripts/bootstrap_sworkstation.sh)
(set -ex
if [ ! -f /etc/debian_version ]; then
    echo "This script should only be run on Debian-based systems."
    exit 1
fi
HOST="${HOST:-localhost}"
CONTEXT="${CONTEXT:-${HOST}}"
ROOT_DOMAIN="${ROOT_DOMAIN:-${HOST}}"
ALIAS="${ALIAS:-${CONTEXT}}"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install \
    --assume-yes \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    bash build-essential gettext git openssl apache2-utils xdg-utils jq sshfs wireguard \
    curl inotify-tools w3m nano openssh-server
curl -sSL https://get.docker.com | sh 
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub | sudo tee -a /root/.ssh/authorized_keys
cat <<EOF >> ~/.ssh/config
Host ${CONTEXT}
    User root
    Hostname ${HOST}
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
EOF
sudo systemctl enable --now ssh
ssh-keyscan -H localhost >> ~/.ssh/known_hosts
ssh "${HOST}" whoami
if docker context ls --format '{{.Name}}' | grep -q "^${CONTEXT}$"; then
    docker context rm "${CONTEXT}" -f
    echo "Docker context '${CONTEXT}' deleted."
fi
docker context create "${CONTEXT}" --docker "host=ssh://${HOST}"
docker context use "${CONTEXT}"
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
mkdir -p ~/.config/d.rymcg.tech
cat <<'EOF' > ~/.config/d.rymcg.tech/bashrc
## d.rymcg.tech cli tool:
export EDITOR=${EDITOR:-nano}
export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"
__d.rymcg.tech_cli_alias d
## Fix for the root user to always use the default context:
if [ "$(whoami)" = "root" ]; then
  export DOCKER_CONTEXT=default
fi
EOF
cat <<EOF >> ~/.config/d.rymcg.tech/bashrc
## Add d.rymcg.tech alias for each Docker context:
__d.rymcg.tech_context_alias ${CONTEXT} ${ALIAS}
EOF
cat <<EOF >> ~/.bashrc

## d.rymcg.tech
source ~/.config/d.rymcg.tech/bashrc

EOF
source ~/.bashrc
ROOT_DOMAIN=${ROOT_DOMAIN} USE_ENV=true YES=yes \
d.rymcg.tech tmp-context localhost d.rymcg.tech config
set +x
echo
echo
echo "## Installation finished."
echo "## Log out and log back in (or source ~/.bashrc)"
echo "## Use the '${ALIAS}' alias to manage the local Docker host."
)
