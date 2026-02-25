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
if ! doctl account get >/dev/null 2>&1; then
    confirm yes "doctl is not authenticated. Run 'doctl auth init' now" "?" || fault "doctl is not authenticated."
    doctl auth init
fi

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
    local name
    if ! name=$(wizard choose "SSH into which droplet?" "${NAMES[@]}" --default "${NAMES[0]}"); then return; fi
    doctl compute ssh "${name}"
}

destroy_droplet() {
    readarray -t NAMES < <(doctl compute droplet list --tag-name "${DROPLET_TAG}" --format Name --no-header)
    if [[ ${#NAMES[@]} -eq 0 ]]; then
        echo "No agent droplets found."
        return
    fi
    local name
    if ! name=$(wizard choose "Destroy which droplet?" "${NAMES[@]}" --default "${NAMES[0]}"); then return; fi
    confirm no "Are you sure you want to destroy '${name}'" "?" || return
    doctl compute droplet delete "${name}" --force
    echo "Droplet '${name}' destroyed."
}

ensure_ssh_key() {
    ## Check for SSH keys, offer to upload if none found:
    readarray -t SSH_KEY_IDS < <(doctl compute ssh-key list --format ID --no-header)
    if [[ ${#SSH_KEY_IDS[@]} -eq 0 ]]; then
        echo ""
        echo "No SSH keys found in your DigitalOcean account."
        confirm yes "Upload a local SSH public key now" "?" || return 1
        upload_ssh_key
    fi
}

create_droplet() {
    ## Ensure SSH keys exist before proceeding:
    if ! ensure_ssh_key; then return; fi

    ask "Enter Woodpecker gRPC address (e.g. woodpecker-grpc.example.com:443)" WOODPECKER_SERVER "${WOODPECKER_SERVER}"
    check_var WOODPECKER_SERVER

    ask "Enter Woodpecker agent secret" WOODPECKER_AGENT_SECRET "${WOODPECKER_AGENT_SECRET}"
    check_var WOODPECKER_AGENT_SECRET

    ask_no_blank "Enter droplet name" DROPLET_NAME

    ## Select region:
    readarray -t REGION_SLUGS < <(doctl compute region list --format Slug --no-header)
    readarray -t REGION_NAMES < <(doctl compute region list --format Name --no-header)
    REGION_OPTIONS=()
    REGION_DEFAULT=""
    for i in "${!REGION_SLUGS[@]}"; do
        local opt=$(printf "%-8s  %s" "${REGION_SLUGS[$i]}" "${REGION_NAMES[$i]}")
        REGION_OPTIONS+=("${opt}")
        [[ "${REGION_SLUGS[$i]}" == "nyc3" ]] && REGION_DEFAULT="${opt}"
    done
    REGION_CHOICE=$(wizard choose "Select region" "${REGION_OPTIONS[@]}" --default "${REGION_DEFAULT}")
    REGION=$(echo "${REGION_CHOICE}" | awk '{print $1}')

    ## Select size:
    readarray -t SIZE_SLUGS < <(doctl compute size list --format Slug --no-header)
    readarray -t SIZE_PRICES < <(doctl compute size list --format PriceHourly --no-header)
    readarray -t SIZE_DISKS < <(doctl compute size list --format Disk --no-header)
    readarray -t SIZE_VCPUS < <(doctl compute size list --format VCPUs --no-header)
    SIZE_OPTIONS=()
    SIZE_DEFAULT=""
    for i in "${!SIZE_SLUGS[@]}"; do
        local opt=$(printf "%-25s  %-3s vCPUs  \$%-10s  %sGB disk" "${SIZE_SLUGS[$i]}" "${SIZE_VCPUS[$i]}" "${SIZE_PRICES[$i]}/hr" "${SIZE_DISKS[$i]}")
        SIZE_OPTIONS+=("${opt}")
        [[ "${SIZE_SLUGS[$i]}" == "s-2vcpu-4gb" ]] && SIZE_DEFAULT="${opt}"
    done
    SIZE_CHOICE=$(wizard choose "Select size" "${SIZE_OPTIONS[@]}" --default "${SIZE_DEFAULT}")
    SIZE=$(echo "${SIZE_CHOICE}" | awk '{print $1}')

    ## Select image:
    IMAGE=$(wizard choose "Select image" "debian-13-x64" --default "debian-13-x64")

    ## Select SSH key:
    echo ""
    readarray -t SSH_KEY_IDS < <(doctl compute ssh-key list --format ID --no-header)
    readarray -t SSH_KEY_NAMES < <(doctl compute ssh-key list --format Name --no-header)
    SSH_KEY_OPTIONS=()
    for i in "${!SSH_KEY_IDS[@]}"; do
        SSH_KEY_OPTIONS+=("${SSH_KEY_NAMES[$i]} (${SSH_KEY_IDS[$i]})")
    done
    local SSH_KEY_CHOICE
    if ! SSH_KEY_CHOICE=$(wizard choose "Which SSH key?" "${SSH_KEY_OPTIONS[@]}" --default "${SSH_KEY_OPTIONS[0]}"); then return; fi
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
    confirm yes "Create this droplet" "?" || return

    echo "Creating droplet '${DROPLET_NAME}', please wait..."
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

list_ssh_keys() {
    echo ""
    echo "## SSH keys on DigitalOcean:"
    doctl compute ssh-key list --format ID,Name,FingerPrint
    echo ""
}

upload_ssh_key() {
    ## Collect keys from agent and from pubkey files, deduplicating by fingerprint:
    local KEY_OPTIONS=()
    local KEY_SOURCES=()
    declare -A SEEN_KEYS

    if ssh-add -L &>/dev/null; then
        while IFS= read -r line; do
            local fingerprint=$(echo "${line}" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')
            if [[ -n "${fingerprint}" && -z "${SEEN_KEYS[${fingerprint}]}" ]]; then
                SEEN_KEYS[${fingerprint}]=1
                local keytype=$(echo "${line}" | awk '{print $1}')
                KEY_OPTIONS+=("agent: ${keytype} ${fingerprint}")
                KEY_SOURCES+=("agent:${line}")
            fi
        done < <(ssh-add -L)
    fi

    while IFS= read -r pubfile; do
        local fingerprint=$(ssh-keygen -lf "${pubfile}" 2>/dev/null | awk '{print $2}')
        if [[ -n "${fingerprint}" && -z "${SEEN_KEYS[${fingerprint}]}" ]]; then
            SEEN_KEYS[${fingerprint}]=1
            KEY_OPTIONS+=("file: ${pubfile}")
            KEY_SOURCES+=("file:${pubfile}")
        fi
    done < <(find ~/.ssh -name '*.pub' -type f 2>/dev/null)

    if [[ ${#KEY_OPTIONS[@]} -eq 0 ]]; then
        error "No public keys found in ssh-agent or ~/.ssh/"
        return
    fi

    local choice
    if ! choice=$(wizard choose "Select public key to upload" "${KEY_OPTIONS[@]}" --default "${KEY_OPTIONS[0]}"); then return; fi

    local source=""
    for i in "${!KEY_OPTIONS[@]}"; do
        if [[ "${KEY_OPTIONS[$i]}" == "${choice}" ]]; then
            source="${KEY_SOURCES[$i]}"
            break
        fi
    done

    local keyname
    ask "Enter a name for this key" keyname "woodpecker-agent"

    if [[ "${source}" == agent:* ]]; then
        local pubkey_data="${source#agent:}"
        local tmpfile=$(mktemp)
        echo "${pubkey_data}" > "${tmpfile}"
        doctl compute ssh-key import "${keyname}" --public-key-file "${tmpfile}"
        rm -f "${tmpfile}"
    else
        local pubfile="${source#file:}"
        doctl compute ssh-key import "${keyname}" --public-key-file "${pubfile}"
    fi
    echo "SSH key '${keyname}' uploaded."
}

delete_ssh_key() {
    readarray -t SSH_KEY_IDS < <(doctl compute ssh-key list --format ID --no-header)
    readarray -t SSH_KEY_NAMES < <(doctl compute ssh-key list --format Name --no-header)
    if [[ ${#SSH_KEY_IDS[@]} -eq 0 ]]; then
        echo "No SSH keys found."
        return
    fi
    local KEY_OPTIONS=()
    for i in "${!SSH_KEY_IDS[@]}"; do
        KEY_OPTIONS+=("${SSH_KEY_NAMES[$i]} (${SSH_KEY_IDS[$i]})")
    done
    local choice
    if ! choice=$(wizard choose "Delete which SSH key?" "${KEY_OPTIONS[@]}" --default "${KEY_OPTIONS[0]}"); then return; fi
    local key_id=$(echo "${choice}" | grep -oP '\(\K[0-9]+(?=\))')
    confirm no "Are you sure you want to delete '${choice}'" "?" || return
    doctl compute ssh-key delete "${key_id}" --force
    echo "SSH key deleted."
}

manage_ssh_keys() {
    while :
    do
        list_ssh_keys
        set +e
        wizard menu --once --cancel-code=2 "DigitalOcean SSH Keys:" \
            "Upload SSH key = $0 upload_ssh_key" \
            "Delete SSH key = $0 delete_ssh_key" \
            "Back = exit 2"
        local EXIT_CODE=$?
        set -e
        if [[ "${EXIT_CODE}" == "2" ]]; then
            exit 0
        fi
    done
}

main() {
    while :
    do
        list_droplets
        set +e
        wizard menu --once --cancel-code=2 "Woodpecker Agent Droplets:" \
            "Create new agent droplet = $0 create_droplet" \
            "SSH into agent droplet = $0 ssh_droplet" \
            "Destroy agent droplet = $0 destroy_droplet" \
            "Manage SSH keys on DigitalOcean = $0 manage_ssh_keys" \
            "Exit = exit 2"
        local EXIT_CODE=$?
        set -e
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
