#!/bin/bash
## Quick bootstrap of a d.rymcg.tech Sworkstation for Fedora-based systems.
## Configuration is via environment variables:
##
## SSH_HOST = the SSH host to setup (Default localhost).
## CONTEXT = the name of the Docker context to setup (Default $SSH_HOST).
## ALIASES = the list of contextual aliases for d.rymcg.tech (Default $CONTEXT).
## ROOT_DOMAIN = the root sub-domain used for apps (Default $SSH_HOST).
## 
## You may run this script directly from curl:
## 
## ALIASES=l ROOT_DOMAIN=d.example.com bash <(curl -L https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/_scripts/bootstrap_sworkstation_fedora.sh?raw=true)

export SSH_HOST="${SSH_HOST:-localhost}"
export CONTEXT="${CONTEXT:-${SSH_HOST}}"
export ROOT_DOMAIN="${ROOT_DOMAIN:-${SSH_HOST}}"
IFS=',' read -r -a ALIASES <<< "${ALIASES:-${CONTEXT}}"
export SYSBOX=${SYSBOX:-false}
export SYSBOX_URL=${SYSBOX_URL:-https://downloads.nestybox.com/sysbox/releases/v0.6.4/sysbox-ce_0.6.4-0.linux_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/').rpm}

(set -ex
if ! grep -qi "fedora" /etc/os-release; then
    echo "This script should only be run on Fedora-based systems."
    exit 1
fi

if [[ "${SYSBOX}" == "true" ]]; then
    echo "Sorry, Sysbox is not supported on Fedora."
    exit 1
fi

## Install Fedora package dependencies:
sudo dnf -y update
sudo dnf install -y \
    bash gcc gcc-c++ gettext git openssl httpd-tools xdg-utils jq sshfs wireguard-tools \
    curl inotify-tools w3m nano openssh-server moreutils

## Install Docker:
sudo dnf -y install dnf-plugins-core
sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker

## Add SSH configuration for root@localhost:
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub | sudo tee -a /root/.ssh/authorized_keys
remove_ssh_host_entry() {
    local host_name="$1"
    if [[ -f ~/.ssh/config ]]; then
        sed -i "/^Host ${host_name}$/,/^Host /{ /^Host ${host_name}$/d; "'/^Host /!d }' ~/.ssh/config
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
sudo systemctl enable --now sshd
ssh-keyscan -H localhost >> ~/.ssh/known_hosts
ssh "${SSH_HOST}" whoami

## Add new Docker context (removing existing if necessary):
if docker context ls --format '{{.Name}}' | grep -q "^${CONTEXT}$"; then
    docker context rm "${CONTEXT}" -f
    echo "Docker context '${CONTEXT}' deleted."
fi
docker context create "${CONTEXT}" --docker "host=ssh://${SSH_HOST}"
docker context use "${CONTEXT}"

## Clone the d.rymcg.tech repository:
if [[ ! -e ${HOME}/git/vendor/enigmacurry/d.rymcg.tech ]]; then
    git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
        ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
fi

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
## Add d.rymcg.tech alias for each Docker context:
EOF
for i in "${!ALIASES[@]}"; do
    d_alias="${ALIASES[$i]}"
    
    if [[ $i -eq 0 ]]; then
        # First alias
        cat <<EOF >> ~/.config/d.rymcg.tech/bashrc
__d.rymcg.tech_context_alias ${CONTEXT} ${d_alias}
EOF
    else
        # Second and subsequent aliases
        cat <<EOF >> ~/.config/d.rymcg.tech/bashrc
__d.rymcg.tech_context_alias ${d_alias} ${d_alias}
EOF
    fi
done
echo >> ~/.bashrc
cat <<EOF >> ~/.bashrc
## d.rymcg.tech
source ~/.config/d.rymcg.tech/bashrc
EOF
echo >> ~/.bashrc
source ~/.bashrc

## Configure d.rymcg.tech:
ROOT_DOMAIN=${ROOT_DOMAIN} USE_ENV=true YES=yes \
d.rymcg.tech tmp-context localhost d.rymcg.tech config

## Done
set +x
echo
echo
echo "## Installation finished."
echo "## Log out and log back in (or source ~/.bashrc)"
echo "## Use the '${ALIASES}' alias to manage the local Docker host."
)
