#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TEMPLATE_DIR="${SCRIPT_DIR}/templates/deploy-pipeline-template"

BIN=$(dirname "${SCRIPT_DIR}")
source "${BIN}/_scripts/funcs.sh"

wizard() {
    local subcmd="$1"; shift
    local rc=0
    case "${subcmd}" in
        confirm|choose)
            d.rymcg.tech script wizard "${subcmd}" --cancel-code=2 "$@" || rc=$?
            ;;
        *)
            d.rymcg.tech script wizard "${subcmd}" "$@" || rc=$?
            ;;
    esac
    if [[ $rc -eq 2 || $rc -ge 128 ]]; then
        exit 130
    fi
    return $rc
}

echo "=== Scaffold a new deployment pipeline repo ==="
echo ""

NAME=$(wizard ask "Repo name" "my-deploy")

# Default output directory: ~/git/vendor/<username> if git user.name is a
# single word, otherwise ~/git/vendor
_GIT_USER=$(git config --global user.name 2>/dev/null || true)
if [[ -n "${_GIT_USER}" && "${_GIT_USER}" != *" "* ]]; then
    _DEFAULT_OUTPUT="${HOME}/git/vendor/${_GIT_USER,,}"
else
    _DEFAULT_OUTPUT="${HOME}/git"
fi
OUTPUT_DIR=$(wizard ask "Output directory" "${_DEFAULT_OUTPUT}")

DEST="${OUTPUT_DIR}/${NAME}"
if [[ -e "${DEST}" ]]; then
    echo "Error: ${DEST} already exists."
    exit 1
fi

REGISTRY=$(wizard ask "Forgejo hostname (e.g. git.example.com)")
REPO_OWNER=$(wizard ask "Repository owner (Forgejo user must be a member of Woodpecker CI Org)")
IMAGE_SOURCE=$(wizard choose "Where is the d-rymcg-tech Docker image hosted?" "ghcr.io (GitHub Container Registry)" "Forgejo registry (${REGISTRY})")
if [[ "${IMAGE_SOURCE}" == "ghcr.io"* ]]; then
    IMAGE_SOURCE=ghcr
else
    IMAGE_SOURCE=forgejo
fi
CONTEXT_NAME=$(wizard ask "Context name for initial config (SSH/Docker host alias)")
SOPS_CONFIG="config/${CONTEXT_NAME}.sops.env"

BAO_CACERT=false
BAO_CLIENT_CERT=false
BAO_CLIENT_KEY=false
wizard confirm "Does your OpenBao server use a private CA certificate?" no && BAO_CACERT=true
wizard confirm "Does your OpenBao server require mTLS client authentication?" no && { BAO_CLIENT_CERT=true; BAO_CLIENT_KEY=true; }

echo ""
echo "Creating ${DEST} ..."

# Copy template files (excluding the .j2 template)
mkdir -p "${DEST}/.woodpecker" "${DEST}/config"
cp "${TEMPLATE_DIR}/Makefile" "${DEST}/Makefile"
cp "${TEMPLATE_DIR}/admin.sh" "${DEST}/admin.sh"
cp "${TEMPLATE_DIR}/README.md" "${DEST}/README.md"
cp "${TEMPLATE_DIR}/CLAUDE.md" "${DEST}/CLAUDE.md"
cp "${TEMPLATE_DIR}/.gitignore" "${DEST}/.gitignore"
cp "${TEMPLATE_DIR}/config/.gitignore" "${DEST}/config/.gitignore"

# Render deploy.yaml from the .j2 template
RENDER_SCRIPT=$(mktemp --suffix=.py)
trap 'rm -f "${RENDER_SCRIPT}"' EXIT
cat > "${RENDER_SCRIPT}" << 'PYEOF'
# /// script
# requires-python = ">=3.11"
# dependencies = ["jinja2"]
# ///
import argparse
from pathlib import Path
from jinja2 import Environment, FileSystemLoader

parser = argparse.ArgumentParser()
parser.add_argument("--template-dir", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--registry", required=True)
parser.add_argument("--sops-config", required=True)
parser.add_argument("--bao-cacert", action="store_true")
parser.add_argument("--bao-client-cert", action="store_true")
parser.add_argument("--bao-client-key", action="store_true")
parser.add_argument("--image-source", default="ghcr", choices=["ghcr", "forgejo"])
args = parser.parse_args()

env = Environment(
    loader=FileSystemLoader(args.template_dir),
    keep_trailing_newline=True,
    trim_blocks=True,
    lstrip_blocks=True,
)
template = env.get_template("deploy.yaml.j2")
output = Path(args.output)
output.write_text(template.render(
    registry=args.registry,
    sops_config=args.sops_config,
    image_source=args.image_source,
    bao_cacert=args.bao_cacert,
    bao_client_cert=args.bao_client_cert,
    bao_client_key=args.bao_client_key,
))
print(f"Rendered {output}")
PYEOF

RENDER_ARGS=("--template-dir" "${TEMPLATE_DIR}/.woodpecker"
             "--output" "${DEST}/.woodpecker/deploy.yaml"
             "--registry" "${REGISTRY}" "--sops-config" "${SOPS_CONFIG}"
             "--image-source" "${IMAGE_SOURCE}")
[[ "${BAO_CACERT}" == true ]] && RENDER_ARGS+=("--bao-cacert")
[[ "${BAO_CLIENT_CERT}" == true ]] && RENDER_ARGS+=("--bao-client-cert")
[[ "${BAO_CLIENT_KEY}" == true ]] && RENDER_ARGS+=("--bao-client-key")
uv run "${RENDER_SCRIPT}" "${RENDER_ARGS[@]}"

# Replace __NAME__ with the repo name in all text files
find "${DEST}" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.yaml' -o -name 'Makefile' \) \
    -exec sed -i "s/__NAME__/${NAME}/g" {} +

# Make admin.sh executable
chmod +x "${DEST}/admin.sh"

# Initialize git repo with remote
git -C "${DEST}" init
git -C "${DEST}" add -A
git -C "${DEST}" commit -m "Initial commit"
git -C "${DEST}" remote add origin "git@${REGISTRY}:${REPO_OWNER}/${NAME}.git"

echo ""
echo "=== Done! ==="
echo ""
echo "Your new deployment repo is ready at: ${DEST}"
echo "Remote: git@${REGISTRY}:${REPO_OWNER}/${NAME}.git"
echo ""
echo "=== Prerequisites (if not already done) ==="
echo ""
echo "1. Create a 'woodpecker' org on Forgejo:"
echo "     Log in as 'root' -> https://${REGISTRY}/admin/orgs"
echo ""
echo "2. Deploy Woodpecker CI:"
echo "     d make woodpecker config"
echo "     d make woodpecker install"
echo ""
echo "3. Create a dedicated Forgejo account for CI (e.g. '${REPO_OWNER}'):"
echo "     Log in as 'root' -> https://${REGISTRY}/admin/users"
echo ""
echo "4. Add the CI account to the 'woodpecker' org on Forgejo:"
echo "     Log in as 'root' -> https://${REGISTRY}/org/woodpecker/teams"
echo "     Create a team (e.g. 'CI') and add '${REPO_OWNER}' to it"
echo ""
echo "5. Add your workstation's SSH public key to the CI account so you can push:"
echo "     Log in as '${REPO_OWNER}' -> https://${REGISTRY}/user/settings/keys"
echo ""
echo "   Your public keys:"
ssh-add -L 2>/dev/null | while read -r key; do echo "     ${key}"; done || echo "     (none found — is ssh-agent running?)"
echo ""
echo "6. Log in to Woodpecker as the CI account and generate an API token:"
echo "     Log in as '${REPO_OWNER}' -> https://woodpecker.example.com/user"
echo ""
echo "=== Next steps ==="
echo ""
echo "  cd ${DEST}"
echo "  export WOODPECKER_SERVER=https://woodpecker.example.com"
echo "  export WOODPECKER_TOKEN=<your-token>"
echo "  make ci"
