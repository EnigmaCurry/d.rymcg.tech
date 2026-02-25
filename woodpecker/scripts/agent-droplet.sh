#!/bin/bash
## Manage Woodpecker agent droplets on DigitalOcean.
## Usage: agent-droplet.sh

SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
ROOT_DIR=$(readlink -f "${SCRIPT_DIR}/../..")
BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

set -eo pipefail

DROPLET_TAG="woodpecker-agent"

## Check prerequisites:
command -v doctl >/dev/null || fault "doctl is not installed. See https://docs.digitalocean.com/reference/doctl/how-to/install/"
doctl account get >/dev/null 2>&1 || fault "doctl is not authenticated. Run: doctl auth init"

export WOODPECKER_SERVER="${DEFAULT_WOODPECKER_SERVER}"
export WOODPECKER_AGENT_SECRET="${DEFAULT_WOODPECKER_AGENT_SECRET}"

list_droplets() {
    echo ""
    echo "## Woodpecker agent droplets:"
    doctl compute droplet list --tag-name "${DROPLET_TAG}" --format ID,Name,PublicIPv4,Region,SizeSlug,Status
    echo ""
}

ssh_droplet() {
    readarray -t NAMES < <(doctl compute droplet list --tag-name "${DROPLET_TAG}" --format Name --no-header)
    if [[ ${#NAMES[@]} -eq 0 ]]; then
        echo "No agent droplets found."
        return
    fi
    local name=$(wizard choose "SSH into which droplet?" "${NAMES[@]}" --default "${NAMES[0]}")
    doctl compute ssh "${name}"
}

destroy_droplet() {
    readarray -t NAMES < <(doctl compute droplet list --tag-name "${DROPLET_TAG}" --format Name --no-header)
    if [[ ${#NAMES[@]} -eq 0 ]]; then
        echo "No agent droplets found."
        return
    fi
    local name=$(wizard choose "Destroy which droplet?" "${NAMES[@]}" --default "${NAMES[0]}")
    confirm no "Are you sure you want to destroy '${name}'?" || return
    doctl compute droplet delete "${name}" --force
    echo "Droplet '${name}' destroyed."
}

create_droplet() {
    ## Defaults:
    local DEFAULT_REGION="nyc3"
    local DEFAULT_SIZE="s-2vcpu-4gb"
    local DEFAULT_IMAGE="debian-13-x64"

    ask "Enter droplet name" DROPLET_NAME
    check_var DROPLET_NAME

    ask "Enter Woodpecker gRPC address (e.g. woodpecker-grpc.example.com:443)" WOODPECKER_SERVER "${WOODPECKER_SERVER}"
    check_var WOODPECKER_SERVER

    ask "Enter Woodpecker agent secret" WOODPECKER_AGENT_SECRET "${WOODPECKER_AGENT_SECRET}"
    check_var WOODPECKER_AGENT_SECRET

    ask "Enter region" REGION "${DEFAULT_REGION}"
    ask "Enter size" SIZE "${DEFAULT_SIZE}"
    ask "Enter image" IMAGE "${DEFAULT_IMAGE}"

    ## Select SSH key:
    echo ""
    readarray -t SSH_KEY_IDS < <(doctl compute ssh-key list --format ID --no-header)
    readarray -t SSH_KEY_NAMES < <(doctl compute ssh-key list --format Name --no-header)
    if [[ ${#SSH_KEY_IDS[@]} -eq 0 ]]; then
        fault "No SSH keys found in your DigitalOcean account. Add one first."
    fi
    SSH_KEY_OPTIONS=()
    for i in "${!SSH_KEY_IDS[@]}"; do
        SSH_KEY_OPTIONS+=("${SSH_KEY_NAMES[$i]} (${SSH_KEY_IDS[$i]})")
    done
    SSH_KEY_CHOICE=$(wizard choose "Which SSH key?" "${SSH_KEY_OPTIONS[@]}" --default "${SSH_KEY_OPTIONS[0]}")
    SSH_KEY=$(echo "${SSH_KEY_CHOICE}" | grep -oP '\(\K[0-9]+(?=\))')

    ## Build cloud-init user data:
    USER_DATA=$(cat <<USERDATA
#!/bin/bash
set -eo pipefail

## Install Woodpecker agent:
RELEASE_VERSION=\$(curl -s https://api.github.com/repos/woodpecker-ci/woodpecker/releases/latest | grep -Po '"tag_name":\s"v\K[^"]+')
curl -fLO "https://github.com/woodpecker-ci/woodpecker/releases/download/v\${RELEASE_VERSION}/woodpecker-agent_\${RELEASE_VERSION}_amd64.deb"
apt-get update
apt-get install -y ./woodpecker-agent_\${RELEASE_VERSION}_amd64.deb
rm -f woodpecker-agent_\${RELEASE_VERSION}_amd64.deb

## Install Docker (needed as the pipeline backend):
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \$(. /etc/os-release && echo "\$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

## Create woodpecker user and add to docker group:
id woodpecker &>/dev/null || useradd --system --shell /usr/sbin/nologin woodpecker
usermod -aG docker woodpecker

## Install Nix:
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm

## Configure agent:
cat > /etc/woodpecker/woodpecker-agent.env <<EOF
WOODPECKER_SERVER=${WOODPECKER_SERVER}
WOODPECKER_AGENT_SECRET=${WOODPECKER_AGENT_SECRET}
WOODPECKER_GRPC_SECURE=true
WOODPECKER_LOG_LEVEL=info
WOODPECKER_BACKEND=docker
EOF
chmod 600 /etc/woodpecker/woodpecker-agent.env

## Enable and start:
systemctl enable woodpecker-agent
systemctl start woodpecker-agent
USERDATA
)

    echo ""
    echo "## Summary:"
    echo "  Droplet name:  ${DROPLET_NAME}"
    echo "  Region:        ${REGION}"
    echo "  Size:          ${SIZE}"
    echo "  Image:         ${IMAGE}"
    echo "  SSH key:       ${SSH_KEY}"
    echo "  gRPC address:  ${WOODPECKER_SERVER}"
    echo ""
    confirm yes "Create this droplet?" || return

    doctl compute droplet create "${DROPLET_NAME}" \
        --region "${REGION}" \
        --size "${SIZE}" \
        --image "${IMAGE}" \
        --ssh-keys "${SSH_KEY}" \
        --user-data "${USER_DATA}" \
        --tag-names "${DROPLET_TAG}" \
        --wait

    echo ""
    echo "Droplet created."
    echo "Check cloud-init status with: doctl compute ssh ${DROPLET_NAME} -- tail -f /var/log/cloud-init-output.log"
    list_droplets
}

main() {
    while :
    do
        list_droplets
        wizard menu --once --cancel-code=2 "Woodpecker Agent Droplets:" \
            "Create new agent droplet = $0 create_droplet" \
            "SSH into agent droplet = $0 ssh_droplet" \
            "Destroy agent droplet = $0 destroy_droplet" \
            "Exit = exit 0"
        local EXIT_CODE=$?
        if [[ "${EXIT_CODE}" == "2" ]]; then
            exit 0
        fi
    done
}

## Allow calling individual functions or run main menu:
if [[ -n "$1" ]]; then
    "$@"
else
    main
fi
