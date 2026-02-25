#!/bin/bash
## Create a DigitalOcean droplet and install Woodpecker agent natively via deb package.
## Usage: ./create-agent-droplet.sh

SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
ROOT_DIR=$(readlink -f "${SCRIPT_DIR}/../..")
BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

set -eo pipefail

## Check prerequisites:
command -v doctl >/dev/null || fault "doctl is not installed. See https://docs.digitalocean.com/reference/doctl/how-to/install/"
doctl account get >/dev/null 2>&1 || fault "doctl is not authenticated. Run: doctl auth init"

## Defaults:
DEFAULT_REGION="nyc3"
DEFAULT_SIZE="s-2vcpu-4gb"
DEFAULT_IMAGE="debian-13-x64"

ask "Enter droplet name" DROPLET_NAME
check_var DROPLET_NAME

ask "Enter Woodpecker gRPC address (e.g. woodpecker-grpc.example.com:443)" WOODPECKER_SERVER "${DEFAULT_WOODPECKER_SERVER}"
check_var WOODPECKER_SERVER

ask "Enter Woodpecker agent secret" WOODPECKER_AGENT_SECRET "${DEFAULT_WOODPECKER_AGENT_SECRET}"
check_var WOODPECKER_AGENT_SECRET

ask "Enter region" REGION "${DEFAULT_REGION}"
ask "Enter size" SIZE "${DEFAULT_SIZE}"
ask "Enter image" IMAGE "${DEFAULT_IMAGE}"

## Select SSH key:
echo ""
echo "Available SSH keys:"
doctl compute ssh-key list --format ID,Name,FingerPrint
echo ""
ask "Enter SSH key ID or fingerprint" SSH_KEY
check_var SSH_KEY

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

## Add woodpecker user to docker group:
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
echo "Creating droplet '${DROPLET_NAME}' in ${REGION} (${SIZE}, ${IMAGE})..."
doctl compute droplet create "${DROPLET_NAME}" \
    --region "${REGION}" \
    --size "${SIZE}" \
    --image "${IMAGE}" \
    --ssh-keys "${SSH_KEY}" \
    --user-data "${USER_DATA}" \
    --tag-names "woodpecker-agent" \
    --wait

echo ""
echo "Droplet created. Waiting for cloud-init to complete..."
echo "You can check status with: doctl compute ssh ${DROPLET_NAME} -- tail -f /var/log/cloud-init-output.log"
echo ""
doctl compute droplet list --tag-name woodpecker-agent --format ID,Name,PublicIPv4,Status
