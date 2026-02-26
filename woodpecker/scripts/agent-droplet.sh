#!/bin/bash
## Manage Woodpecker agent droplets on DigitalOcean.
## Thin wrapper around gumdrop with Woodpecker-specific hooks.

SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
ROOT_DIR=$(readlink -f "${SCRIPT_DIR}/../..")
BIN=${ROOT_DIR}/_scripts

## Configure gumdrop for Woodpecker agents:
export GUMDROP_TAG="woodpecker-agent"
export GUMDROP_LABEL="Woodpecker Agent"
export GUMDROP_SSH_KEY_NAME="woodpecker-agent"
export GUMDROP_IMAGES="debian-13-x64"

export WOODPECKER_SERVER="${DEFAULT_WOODPECKER_SERVER}"
export WOODPECKER_AGENT_SECRET="${DEFAULT_WOODPECKER_AGENT_SECRET}"

## Hook: prompt for gRPC address and agent secret before create:
gumdrop_pre_create_hook() {
    ask "Enter Woodpecker gRPC address (e.g. woodpecker-grpc.example.com:443)" WOODPECKER_SERVER "${WOODPECKER_SERVER}"
    check_var WOODPECKER_SERVER

    ask "Enter Woodpecker agent secret" WOODPECKER_AGENT_SECRET "${WOODPECKER_AGENT_SECRET}"
    check_var WOODPECKER_AGENT_SECRET

    WOODPECKER_BACKEND=$(wizard choose "Choose the agent backend" "docker" "local" --default "docker")
    export WOODPECKER_BACKEND
}

## Hook: generate Woodpecker cloud-init user-data:
gumdrop_user_data_hook() {
    cat <<USERDATA
#!/bin/bash
set -eo pipefail

## Install Woodpecker agent:
RELEASE_VERSION=\$(curl -s https://api.github.com/repos/woodpecker-ci/woodpecker/releases/latest | grep -Po '"tag_name":\s"v\K[^"]+')
curl -fLO "https://github.com/woodpecker-ci/woodpecker/releases/download/v\${RELEASE_VERSION}/woodpecker-agent_\${RELEASE_VERSION}_amd64.deb"
apt-get update
apt-get install -y ./woodpecker-agent_\${RELEASE_VERSION}_amd64.deb
rm -f woodpecker-agent_\${RELEASE_VERSION}_amd64.deb
USERDATA

    if [[ "${WOODPECKER_BACKEND}" == "docker" ]]; then
        cat <<USERDATA

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
USERDATA
    else
        cat <<USERDATA

## Create woodpecker user:
id woodpecker &>/dev/null || useradd --system --shell /usr/sbin/nologin woodpecker
USERDATA
    fi

    cat <<USERDATA

## Install Nix:
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

## Install common dev tools via Nix:
nix profile add \\
  nixpkgs#git \\
  nixpkgs#git-lfs \\
  nixpkgs#gnumake \\
  nixpkgs#curl \\
  nixpkgs#wget \\
  nixpkgs#jq \\
  nixpkgs#bash \\
  nixpkgs#coreutils \\
  nixpkgs#findutils \\
  nixpkgs#gnugrep \\
  nixpkgs#gnused \\
  nixpkgs#gawk \\
  nixpkgs#gnutar \\
  nixpkgs#gzip \\
  nixpkgs#parted \\
  nixpkgs#gptfdisk \\
  nixpkgs#btrfs-progs \\
  nixpkgs#dosfstools \\
  nixpkgs#psmisc \\
  nixpkgs#rclone

## Install sudo (needed for image builds):
apt-get install -y sudo

## Grant woodpecker user passwordless sudo (needed for image builds):
echo "woodpecker ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/woodpecker
chmod 440 /etc/sudoers.d/woodpecker

## Create notify script for webhook notifications:
cat > /usr/local/bin/notify <<'NOTIFY_SCRIPT'
#!/bin/bash
## Send an HTML notification to a webhook.
## Usage: notify "<html>" or echo "<html>" | notify
set -eo pipefail

if [[ -n "\$1" ]]; then
    HTML="\$1"
else
    HTML="\$(cat)"
fi

if [[ -z "\${NOTIFICATION_WEBHOOK_URL}" ]]; then
    if [[ "\${NOTIFICATION_WEBHOOK_ENFORCE}" == "true" ]]; then
        echo "ERROR: NOTIFICATION_WEBHOOK_URL is not set and NOTIFICATION_WEBHOOK_ENFORCE=true" >&2
        exit 1
    else
        echo "WARNING: NOTIFICATION_WEBHOOK_URL is not set, skipping notification" >&1
        exit 0
    fi
fi

JSON=\$(jq -n --arg html "\${HTML}" '{html: \$html}')
HTTP_CODE=\$(curl -s -o /dev/null -w '%{http_code}' -X POST \\
    -H 'Content-Type: application/json' \\
    -d "\${JSON}" \\
    "\${NOTIFICATION_WEBHOOK_URL}")

if [[ "\${HTTP_CODE}" -lt 200 || "\${HTTP_CODE}" -ge 300 ]]; then
    if [[ "\${NOTIFICATION_WEBHOOK_ENFORCE}" == "true" ]]; then
        echo "ERROR: Webhook returned HTTP \${HTTP_CODE} (expected 2xx)" >&2
        exit 1
    else
        echo "WARNING: Webhook returned HTTP \${HTTP_CODE} (expected 2xx)" >&1
    fi
fi
NOTIFY_SCRIPT
chmod +x /usr/local/bin/notify

## Configure agent:
cat > /etc/woodpecker/woodpecker-agent.env <<EOF
WOODPECKER_SERVER=${WOODPECKER_SERVER}
WOODPECKER_AGENT_SECRET=${WOODPECKER_AGENT_SECRET}
WOODPECKER_GRPC_SECURE=true
WOODPECKER_LOG_LEVEL=info
WOODPECKER_BACKEND=${WOODPECKER_BACKEND}
PATH=/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
chmod 600 /etc/woodpecker/woodpecker-agent.env

## Enable and start:
systemctl enable woodpecker-agent
systemctl start woodpecker-agent
USERDATA
}

## Hook: print gRPC address in create summary:
gumdrop_summary_hook() {
    echo "  gRPC address:  ${WOODPECKER_SERVER}"
    echo "  Agent backend: ${WOODPECKER_BACKEND}"
}

source ${BIN}/gumdrop

## Dispatch: function name from args, or main menu:
if [[ -n "$1" ]]; then
    "$@"
else
    gumdrop_main
fi
