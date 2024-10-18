#!/bin/bash
## Quick bootstrap of a d.rymcg.tech Sworkstation:
## (Only requires a freshly installed Debian-like host.)
## Configuration is via environment variables:
##
## SSH_HOST = the SSH host to setup (Default localhost).
## CONTEXT = the name of the Docker context to setup (Default $SSH_HOST).
## ALIAS = the contextual alias for d.rymcg.tech (Default $CONTEXT).
## ROOT_DOMAIN = the root sub-domain used for apps (Default $SSH_HOST).
## SYSBOX = boolean to specify whether to install Sysbox or not.
## 
## You may run this script directly from curl:
## 
## ALIAS=l ROOT_DOMAIN=d.example.com SYSBOX=false bash <(curl -L https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/_scripts/bootstrap_sworkstation.sh?raw=true)
##
## This whole script is written in a sub-shell, so it is safe to copy
## and paste it directly into your bash shell, just remember to set the vars first.
##

export SSH_HOST="${SSH_HOST:-localhost}"
export CONTEXT="${CONTEXT:-${SSH_HOST}}"
export ROOT_DOMAIN="${ROOT_DOMAIN:-${SSH_HOST}}"
export ALIAS="${ALIAS:-${CONTEXT}}"
export SYSBOX=${SYSBOX:-false}
export SYSBOX_URL=${SYSBOX_URL:-https://downloads.nestybox.com/sysbox/releases/v0.6.4/sysbox-ce_0.6.4-0.linux_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/').deb}

(set -ex
if [ ! -f /etc/debian_version ]; then
    echo "This script should only be run on Debian-based systems."
    exit 1
fi

##
## Install debian package dependencies:
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install \
    --assume-yes \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    bash build-essential gettext git openssl apache2-utils xdg-utils jq sshfs wireguard \
    curl inotify-tools w3m nano openssh-server

##
## Install Docker:
curl -sSL https://get.docker.com | sh

##
## Add SSH configuration for root@localhost:
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub | sudo tee -a /root/.ssh/authorized_keys
remove_ssh_host_entry() {
    local host_name="$1"
    if [[ -f ~/.ssh/config ]]; then
        sed -i "/^Host ${host_name}$/,/^Host /{ /^Host ${host_name}$/d; /^Host /!d }" ~/.ssh/config
    fi
}
remove_ssh_host_entry "${CONTEXT}"
cat <<EOF >> ~/.ssh/config
Host ${CONTEXT}
    User root
    Hostname ${SSH_HOST}
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
EOF
sudo systemctl enable --now ssh
ssh-keyscan -H localhost >> ~/.ssh/known_hosts
ssh "${SSH_HOST}" whoami

##
## Add new Docker context (removing existing if necessary:)
if docker context ls --format '{{.Name}}' | grep -q "^${CONTEXT}$"; then
    docker context rm "${CONTEXT}" -f
    echo "Docker context '${CONTEXT}' deleted."
fi
docker context create "${CONTEXT}" --docker "host=ssh://${SSH_HOST}"
docker context use "${CONTEXT}"

##
## Clone the d.rymcg.tech repository:
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ${HOME}/git/vendor/enigmacurry/d.rymcg.tech

##
## Add the bash shell integration for d.rymcg.tech:
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
echo >> ~/.bashrc
cat <<EOF >> ~/.bashrc
## d.rymcg.tech
source ~/.config/d.rymcg.tech/bashrc
EOF
echo >> ~/.bashrc
source ~/.bashrc

##
## Configure d.rymcg.tech:
ROOT_DOMAIN=${ROOT_DOMAIN} USE_ENV=true YES=yes \
d.rymcg.tech tmp-context localhost d.rymcg.tech config

## Install sysbox:
if [[ "${SYSBOX}" == "true" ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
         jq fuse rsync linux-headers-$(uname -r)
    TMP_FILE=$(mktemp)
    wget -O ${TMP_FILE} "${SYSBOX_URL}"
    dpkg -i ${TMP_FILE}
fi

##
## Done
set +x
echo
echo
echo "## Installation finished."
echo "## Log out and log back in (or source ~/.bashrc)"
echo "## Use the '${ALIAS}' alias to manage the local Docker host."
)
