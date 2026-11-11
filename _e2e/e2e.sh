#!/bin/bash
## e2e.sh - End-to-end smoke test / automatic installer for d.rymcg.tech.
##
## Given a DigitalOcean API token and a subdomain to own (on a domain already
## managed by DigitalOcean DNS), this script - with zero interaction - will:
##
##   1. Create a droplet (cloud-init installs Docker), firewall, and SSH key.
##   2. Create the DNS records (wildcard A, acme-dns delegation).
##   3. Bootstrap the droplet into a self-contained "sworkstation":
##      workstation tooling installed on the droplet itself, with an SSH
##      Docker context pointing back to ssh://localhost.
##   4. Clone d.rymcg.tech onto the droplet from a git remote (default:
##      the public upstream master - testing what a new user would get).
##   5. Non-interactively configure the root context, install acme-dns
##      (self-hosted) and Traefik (acme.sh + acme-dns, wildcard cert),
##      creating the _acme-challenge CNAMEs automatically.
##   6. Install a sampling of apps and verify each HTTPS route externally.
##
## The droplet is KEPT by default (it remains a usable sworkstation);
## use the destroy command to tear everything down.
##
## Usage:
##   export DIGITALOCEAN_ACCESS_TOKEN=...
##   _e2e/e2e.sh up --domain example.com --subdomain e2e
##   _e2e/e2e.sh status --name e2e-e2e
##   _e2e/e2e.sh destroy --name e2e-e2e --yes
##
## See _e2e/README.md for full documentation.

E2E_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
ROOT_DIR=$(readlink -f "${E2E_DIR}/..")
BIN=${ROOT_DIR}/_scripts

## Sourcing gumdrop also sources funcs.sh (confirm, fault, error, stderr):
source "${BIN}/gumdrop"

set -eEo pipefail

## Defaults (flag > env > default):
E2E_DOMAIN="${E2E_DOMAIN:-}"
E2E_SUBDOMAIN="${E2E_SUBDOMAIN:-}"
E2E_NAME="${E2E_NAME:-}"
E2E_REGION="${E2E_REGION:-nyc2}"
E2E_SIZE="${E2E_SIZE:-s-2vcpu-4gb}"
E2E_IMAGE="${E2E_IMAGE:-debian-13-x64}"
E2E_ACME_CA="${E2E_ACME_CA:-acme-staging-v02.api.letsencrypt.org}"
E2E_APPS="${E2E_APPS:-whoami,datetime,it-tools,excalidraw,privatebin}"
E2E_GIT_URL="${E2E_GIT_URL:-https://github.com/EnigmaCurry/d.rymcg.tech.git}"
E2E_GIT_REF="${E2E_GIT_REF:-master}"
E2E_TIMEOUT="${E2E_TIMEOUT:-300}"
E2E_CERT_TIMEOUT="${E2E_CERT_TIMEOUT:-600}"
E2E_SSH_PUBKEY="${E2E_SSH_PUBKEY:-}"
E2E_KEEP_GOING=false
E2E_RESET_ENV=false
E2E_YES=false

## Runtime state (loaded from / saved to the state file):
DROPLET_ID=""
DROPLET_IP=""
FIREWALL_ID=""
SSH_KEY_ID=""
DNS_RECORD_IDS=""
PHASES_DONE=""

CONFIG_DIR="${HOME}/.config/d.rymcg.tech/e2e"
LOG_DIR="${CONFIG_DIR}/logs"
LOG_FILE=""
CURRENT_PHASE=""
_ON_ERROR_RAN=""
_MAIN_PID=$$
REMOTE_REPO='$HOME/git/vendor/enigmacurry/d.rymcg.tech'
PHASES=(preflight provision dns bootstrap rootconfig acme-dns traefik apps verify summary)
RESULTS=()
FAILED_APPS=()

usage() {
    cat <<EOF
e2e.sh - end-to-end smoke test / installer for d.rymcg.tech on DigitalOcean

Usage: e2e.sh <command> [options]

Commands:
  up            Run all phases: ${PHASES[*]}
  phase NAME    Run a single phase by name
  status        Show saved state and droplet status
  destroy       Tear down droplet, firewall, SSH key, and DNS records
  help          Show this help

Options:
  --token TOKEN      DigitalOcean API token (or env DIGITALOCEAN_ACCESS_TOKEN)
  --domain DOMAIN    Parent domain managed by DigitalOcean DNS (required)
  --subdomain SUB    Subdomain for the test to own; ROOT_DOMAIN=SUB.DOMAIN (required)
  --name NAME        Droplet/context/resource name (default: e2e-SUB)
  --region REGION    Droplet region (default: ${E2E_REGION})
  --size SIZE        Droplet size (default: ${E2E_SIZE})
  --image IMAGE      Droplet image (default: ${E2E_IMAGE})
  --staging          Use Let's Encrypt staging CA (default)
  --production       Use Let's Encrypt production CA
  --apps LIST        Comma-separated app list (default: ${E2E_APPS})
  --git-url URL      Git remote to clone on the droplet (default: ${E2E_GIT_URL})
  --git-ref REF      Branch/tag/sha to check out (default: ${E2E_GIT_REF})
  --timeout SECS     Per-wait timeout (default: ${E2E_TIMEOUT})
  --ssh-pubkey PATH  SSH public key to upload (default: ~/.ssh/id_ed25519.pub)
  --keep-going       Continue installing apps after one fails
  --reset-env        Delete the remote .env files before configuring
  --yes              Skip the destroy confirmation
EOF
    exit "${1:-0}"
}

## -------------------------------------------------------------------------
## State file
## -------------------------------------------------------------------------

state_file() { echo "${CONFIG_DIR}/${E2E_NAME}.env"; }

save_state() {
    mkdir -p "${CONFIG_DIR}"
    local f
    f=$(state_file)
    cat > "${f}" <<EOF
## e2e state for '${E2E_NAME}' (do not store secrets here)
E2E_DOMAIN=${E2E_DOMAIN}
E2E_SUBDOMAIN=${E2E_SUBDOMAIN}
E2E_REGION=${E2E_REGION}
E2E_SIZE=${E2E_SIZE}
E2E_IMAGE=${E2E_IMAGE}
E2E_ACME_CA=${E2E_ACME_CA}
E2E_APPS=${E2E_APPS}
E2E_GIT_URL=${E2E_GIT_URL}
E2E_GIT_REF=${E2E_GIT_REF}
DROPLET_ID=${DROPLET_ID}
DROPLET_IP=${DROPLET_IP}
FIREWALL_ID=${FIREWALL_ID}
SSH_KEY_ID=${SSH_KEY_ID}
DNS_RECORD_IDS=${DNS_RECORD_IDS}
PHASES_DONE=${PHASES_DONE}
EOF
    chmod 600 "${f}"
}

state_get() {
    grep -oP "^$1=\K.*" "$(state_file)" 2>/dev/null | head -n 1 || true
}

load_state() {
    ## Adopt the saved runtime resources; CLI flags / env vars keep priority
    ## for everything the user can specify (domain/subdomain fill in only
    ## when not given):
    [[ -f "$(state_file)" ]] || return 0
    DROPLET_ID=$(state_get DROPLET_ID)
    DROPLET_IP=$(state_get DROPLET_IP)
    FIREWALL_ID=$(state_get FIREWALL_ID)
    SSH_KEY_ID=$(state_get SSH_KEY_ID)
    DNS_RECORD_IDS=$(state_get DNS_RECORD_IDS)
    PHASES_DONE=$(state_get PHASES_DONE)
    if [[ -z "${E2E_DOMAIN}" ]]; then
        E2E_DOMAIN=$(state_get E2E_DOMAIN)
    fi
    if [[ -z "${E2E_SUBDOMAIN}" ]]; then
        E2E_SUBDOMAIN=$(state_get E2E_SUBDOMAIN)
    fi
}

mark_phase_done() {
    case ",${PHASES_DONE}," in
        *",$1,"*) ;;
        *) PHASES_DONE="${PHASES_DONE:+${PHASES_DONE},}$1" ;;
    esac
    save_state
}

## -------------------------------------------------------------------------
## Logging and error reporting
## -------------------------------------------------------------------------

setup_logging() {
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/${E2E_NAME}-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee -a "${LOG_FILE}") 2>&1
    echo "## Logging all output to: ${LOG_FILE}"
}

banner() {
    echo ""
    echo "########################################################################"
    echo "## $* ($(date +%H:%M:%S))"
    echo "########################################################################"
}

print_what_now() {
    echo ""
    echo "## WHAT NOW ############################################################"
    [[ -n "${LOG_FILE}" ]] && echo "##  Full log   : ${LOG_FILE}"
    [[ -f "$(state_file)" ]] && echo "##  State file : $(state_file)"
    [[ -n "${DROPLET_IP}" ]] && echo "##  Inspect    : ssh root@${DROPLET_IP}"
    echo "##  Resume     : re-run the same 'up' command (phases are idempotent)"
    echo "##  One phase  : e2e.sh phase ${CURRENT_PHASE:-NAME} --name ${E2E_NAME} ..."
    echo "##  Tear down  : e2e.sh destroy --name ${E2E_NAME} --yes"
    echo "########################################################################"
}

on_exit() {
    local code=$?
    [[ "${BASHPID:-$$}" != "${_MAIN_PID}" ]] && return 0
    ## Print recovery help for failures that bypassed the ERR trap (fault()),
    ## but only once a logged run actually started:
    if [[ ${code} -ne 0 && -z "${_ON_ERROR_RAN}" && -n "${LOG_FILE}" ]]; then
        print_what_now
    fi
}

on_error() {
    local code=$1 cmd=$2 line=$3
    ## In a subshell (e.g. command substitution), anything we print would be
    ## captured by the parent as data - stay silent and just propagate:
    if [[ "${BASHPID:-$$}" != "${_MAIN_PID}" ]]; then
        exit "${code}"
    fi
    _ON_ERROR_RAN=1
    trap - ERR
    set +e
    echo ""
    echo "########################################################################"
    echo "## ERROR in phase '${CURRENT_PHASE:-startup}'"
    echo "##   command : ${cmd}"
    echo "##   exit    : ${code}  (e2e.sh line ${line})"
    echo "########################################################################"
    collect_diagnostics
    print_results
    print_what_now
    exit 1
}

collect_diagnostics() {
    ## Best effort - never masks the original error:
    [[ -z "${DROPLET_IP}" ]] && return 0
    echo ""
    echo "## Collecting diagnostics for phase '${CURRENT_PHASE}' ..."
    case "${CURRENT_PHASE}" in
        provision|bootstrap)
            e2e_remote "cloud-init status; tail -n 50 /var/log/cloud-init-output.log" || true
            ;;
        rootconfig|acme-dns)
            e2e_remote_sh "docker ps -a; make -C acme-dns status FORMAT=json; make -C acme-dns logs-out | tail -n 50" || true
            ;;
        traefik|apps|verify)
            e2e_remote_sh "docker ps -a; make -C traefik status FORMAT=json" || true
            e2e_remote_sh "make -C traefik logs-out service=traefik | tail -n 50" || true
            e2e_remote_sh "make -C traefik logs-out service=acme-sh | tail -n 50" || true
            ;;
    esac
}

print_results() {
    [[ ${#RESULTS[@]} -eq 0 && ${#FAILED_APPS[@]} -eq 0 ]] && return 0
    echo ""
    echo "## Results so far:"
    local row
    for row in "${RESULTS[@]}"; do
        echo "  ${row//|/$'\t'}"
    done
    [[ ${#FAILED_APPS[@]} -gt 0 ]] && echo "  Failed apps: ${FAILED_APPS[*]}"
}

## -------------------------------------------------------------------------
## Remote execution helpers
## -------------------------------------------------------------------------

e2e_remote() {
    ## Run a command on the droplet. stdin is /dev/null, so every d.rymcg.tech
    ## `confirm` prompt takes its non-TTY auto-yes path:
    echo "+ [remote] $*" >&2
    ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
        -o ConnectTimeout=15 "root@${DROPLET_IP}" "$@" < /dev/null
}

e2e_remote_sh() {
    ## Run a shell snippet inside the repo dir with the e2e docker context:
    e2e_remote "set -eo pipefail
cd ${REMOTE_REPO}
export DOCKER_CONTEXT=${E2E_NAME} PATH=\"\$PATH:\$HOME/.local/bin\"
$*"
}

e2e_make() {
    ## e2e_make <project|.> [targets/vars ...] - run make for a project remotely.
    ## Always pass instance=default for projects: scripts like
    ## docker_compose_override read the instance from the environment, and
    ## make only exports variables given on its command line:
    local project="$1"
    shift
    local args=""
    local a
    for a in "$@"; do
        args+=" $(printf '%q' "${a}")"
    done
    [[ "${project}" != "." ]] && args+=" instance=default"
    e2e_remote_sh "make -C $(printf '%q' "${project}")${args}"
}

## -------------------------------------------------------------------------
## DigitalOcean helpers
## -------------------------------------------------------------------------

record_dns_id() {
    case ",${DNS_RECORD_IDS}," in
        *",$1,"*) ;;
        *) DNS_RECORD_IDS="${DNS_RECORD_IDS:+${DNS_RECORD_IDS},}$1" ;;
    esac
    save_state
}

e2e_dns_record() {
    ## e2e_dns_record TYPE NAME DATA [TTL] - idempotent create/update:
    local rtype="$1" rname="$2" rdata="$3" ttl="${4:-300}"
    local line id existing
    line=$(doctl compute domain records list "${E2E_DOMAIN}" \
               --format ID,Type,Name,Data --no-header \
               | awk -v t="${rtype}" -v n="${rname}" '$2==t && $3==n {print; exit}')
    if [[ -n "${line}" ]]; then
        id=$(awk '{print $1}' <<< "${line}")
        existing=$(awk '{print $4}' <<< "${line}")
        if [[ "${existing%.}" == "${rdata%.}" ]]; then
            echo "DNS ${rtype} ${rname} -> ${rdata} (exists, id ${id})"
            record_dns_id "${id}"
            return 0
        fi
        echo "DNS ${rtype} ${rname} -> ${rdata} (updating id ${id}, was ${existing})"
        doctl compute domain records update "${E2E_DOMAIN}" --record-id "${id}" \
              --record-type "${rtype}" --record-name "${rname}" \
              --record-data "${rdata}" --record-ttl "${ttl}" > /dev/null
        record_dns_id "${id}"
        return 0
    fi
    echo "DNS ${rtype} ${rname} -> ${rdata} (creating)"
    id=$(doctl compute domain records create "${E2E_DOMAIN}" \
              --record-type "${rtype}" --record-name "${rname}" \
              --record-data "${rdata}" --record-ttl "${ttl}" \
              --format ID --no-header)
    record_dns_id "${id}"
}

tls_probe() {
    ## Print the certificate subject+issuer served for hostname $1:
    echo | timeout 15 openssl s_client -connect "${DROPLET_IP}:443" \
                 -servername "$1" 2>/dev/null \
        | openssl x509 -noout -subject -issuer 2>/dev/null
}

## -------------------------------------------------------------------------
## Phases
## -------------------------------------------------------------------------

phase_preflight() {
    "${BIN}/check_deps" doctl ssh git jq curl awk sed openssl dig
    if [[ -z "${DIGITALOCEAN_ACCESS_TOKEN:-}" ]]; then
        echo "NOTE: DIGITALOCEAN_ACCESS_TOKEN is not set; relying on existing doctl auth."
    fi
    doctl account get > /dev/null || fault "doctl is not authenticated (set DIGITALOCEAN_ACCESS_TOKEN or --token)."
    doctl compute domain get "${E2E_DOMAIN}" > /dev/null \
        || fault "Domain '${E2E_DOMAIN}' is not managed by this DigitalOcean account."
    if [[ -z "${E2E_SSH_PUBKEY}" ]]; then
        local f
        for f in "${HOME}/.ssh/id_ed25519.pub" "${HOME}/.ssh/id_rsa.pub"; do
            if [[ -f "${f}" ]]; then
                E2E_SSH_PUBKEY="${f}"
                break
            fi
        done
    fi
    [[ -f "${E2E_SSH_PUBKEY}" ]] || fault "No SSH public key found (use --ssh-pubkey)."
    echo "Preflight OK: domain=${E2E_DOMAIN} root_domain=${E2E_ROOT_DOMAIN} name=${E2E_NAME} pubkey=${E2E_SSH_PUBKEY}"
}

phase_provision() {
    ## SSH key - DigitalOcean deduplicates keys by fingerprint, so reuse the
    ## key if the same material already exists under ANY name:
    SSH_KEY_ID=$(doctl compute ssh-key list --format ID,Name --no-header \
                     | awk -v n="${E2E_NAME}" '$2==n {print $1; exit}')
    if [[ -z "${SSH_KEY_ID}" ]]; then
        local fingerprint
        fingerprint=$(ssh-keygen -E md5 -lf "${E2E_SSH_PUBKEY}" \
                          | awk '{print $2}' | sed 's/^MD5://')
        SSH_KEY_ID=$(doctl compute ssh-key list --format ID,FingerPrint --no-header \
                         | awk -v f="${fingerprint}" '$2==f {print $1; exit}')
        if [[ -n "${SSH_KEY_ID}" ]]; then
            echo "Reusing SSH key already in the account (fingerprint ${fingerprint})."
        fi
    fi
    if [[ -z "${SSH_KEY_ID}" ]]; then
        echo "Uploading SSH key '${E2E_NAME}' from ${E2E_SSH_PUBKEY} ..."
        SSH_KEY_ID=$(doctl compute ssh-key import "${E2E_NAME}" \
                         --public-key-file "${E2E_SSH_PUBKEY}" \
                         --format ID --no-header)
    fi
    echo "SSH key id: ${SSH_KEY_ID}"
    save_state

    ## Firewall (22/80/443 web + 53 tcp/udp + 2890 tcp for acme-dns):
    FIREWALL_ID=$(doctl compute firewall list --format ID,Name --no-header \
                      | awk -v n="${E2E_NAME}-fw" '$2==n {print $1; exit}')
    if [[ -z "${FIREWALL_ID}" ]]; then
        echo "Creating firewall '${E2E_NAME}-fw' ..."
        FIREWALL_ID=$(doctl compute firewall create \
            --name "${E2E_NAME}-fw" \
            --inbound-rules "protocol:tcp,ports:22,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:80,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:443,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:53,address:0.0.0.0/0,address:::/0 protocol:udp,ports:53,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:2890,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0" \
            --outbound-rules "protocol:tcp,ports:all,address:0.0.0.0/0,address:::/0 protocol:udp,ports:all,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0" \
            --format ID --no-header)
    fi
    echo "Firewall id: ${FIREWALL_ID}"
    save_state

    ## Droplet:
    DROPLET_ID=$(doctl compute droplet list --format ID,Name --no-header \
                     | awk -v n="${E2E_NAME}" '$2==n {print $1; exit}')
    if [[ -z "${DROPLET_ID}" ]]; then
        echo "Creating droplet '${E2E_NAME}' (${E2E_REGION}/${E2E_SIZE}/${E2E_IMAGE}) ..."
        DROPLET_ID=$(doctl compute droplet create "${E2E_NAME}" \
            --region "${E2E_REGION}" --size "${E2E_SIZE}" --image "${E2E_IMAGE}" \
            --ssh-keys "${SSH_KEY_ID}" --tag-names "${E2E_NAME}" \
            --user-data-file "${E2E_DIR}/user_data_docker_debian.yaml" \
            --wait --format ID --no-header)
    fi
    echo "Droplet id: ${DROPLET_ID}"
    save_state
    if ! doctl compute firewall get "${FIREWALL_ID}" --format DropletIDs --no-header \
            | grep -qw "${DROPLET_ID}"; then
        doctl compute firewall add-droplets "${FIREWALL_ID}" --droplet-ids "${DROPLET_ID}"
    fi

    ## Look up the public IP by droplet id (tag-independent), polling briefly
    ## in case the API has not published it yet:
    echo "Waiting for the droplet's public IP ..."
    local ip_deadline=$((SECONDS + 120))
    DROPLET_IP=""
    while [[ -z "${DROPLET_IP}" ]]; do
        DROPLET_IP=$(doctl compute droplet get "${DROPLET_ID}" \
                         --format PublicIPv4 --no-header 2>/dev/null || true)
        [[ -n "${DROPLET_IP}" ]] && break
        (( SECONDS < ip_deadline )) || fault "Timed out waiting for the droplet's public IP."
        sleep 5
    done
    echo "Droplet ip: ${DROPLET_IP}"
    save_state

    ## Wait for SSH, then for cloud-init (which installs Docker):
    echo "Waiting for SSH on root@${DROPLET_IP} ..."
    local deadline=$((SECONDS + 300))
    until e2e_remote true 2>/dev/null; do
        (( SECONDS < deadline )) || fault "Timed out waiting for SSH."
        sleep 5
    done
    echo "Waiting for cloud-init to finish (installs Docker) ..."
    local rc=0
    e2e_remote "cloud-init status --wait" || rc=$?
    ## Exit code 2 ("recoverable errors") is common on DigitalOcean images:
    if [[ "${rc}" != "0" && "${rc}" != "2" ]]; then
        e2e_remote "tail -n 50 /var/log/cloud-init-output.log" || true
        fault "cloud-init failed (exit ${rc})."
    fi
    ## Verify the daemon directly on its unix socket, independent of whichever
    ## docker context root may already be on (a prior bootstrap switches root
    ## to the ssh://localhost context):
    e2e_remote "docker -H unix:///var/run/docker.sock info -f '{{.ServerVersion}}'"

    ## The DigitalOcean firewall is the real firewall; disable any host ufw:
    e2e_remote "ufw disable 2>/dev/null; systemctl mask ufw 2>/dev/null; true"

    ## Local ~/.ssh/config entry for operator convenience (idempotent):
    local ssh_config="${HOME}/.ssh/config"
    mkdir -p "${HOME}/.ssh"
    touch "${ssh_config}"
    chmod 600 "${ssh_config}"
    sed -i "/^Host ${E2E_NAME}$/,/^Host /{ /^Host ${E2E_NAME}$/d; "'/^Host /!d }' "${ssh_config}"
    cat <<EOF >> "${ssh_config}"

Host ${E2E_NAME}
     Hostname ${DROPLET_IP}
     User root
     ControlMaster auto
     ControlPersist yes
     ControlPath /tmp/ssh-%u-%r@%h:%p
EOF
    echo "Added 'Host ${E2E_NAME}' to ${ssh_config}"
}

phase_dns() {
    [[ -n "${DROPLET_IP}" ]] || fault "No droplet IP (run the provision phase first)."
    e2e_dns_record A "${E2E_SUBDOMAIN}" "${DROPLET_IP}"
    e2e_dns_record A "*.${E2E_SUBDOMAIN}" "${DROPLET_IP}"
    e2e_dns_record A "acme-dns.${E2E_SUBDOMAIN}" "${DROPLET_IP}"
    e2e_dns_record A "auth.acme-dns.${E2E_SUBDOMAIN}" "${DROPLET_IP}"
    e2e_dns_record NS "acme-dns.${E2E_SUBDOMAIN}" "auth.acme-dns.${E2E_SUBDOMAIN}.${E2E_DOMAIN}."
}

phase_bootstrap() {
    [[ -n "${DROPLET_IP}" ]] || fault "No droplet IP (run the provision phase first)."
    echo "Bootstrapping sworkstation (context=${E2E_NAME}, git=${E2E_GIT_URL} @ ${E2E_GIT_REF}) ..."
    ## Upload the script, then execute it in a separate session. Do NOT use
    ## `bash -s` with the script on stdin: any stdin-reading command inside
    ## the script (e.g. ssh) would consume the rest of the script text and
    ## bash would exit 0 early, silently skipping the remaining steps:
    echo "+ [remote] upload _e2e/lib/remote_bootstrap.sh" >&2
    ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "root@${DROPLET_IP}" \
        "cat > /root/.e2e_remote_bootstrap.sh" \
        < "${E2E_DIR}/lib/remote_bootstrap.sh"
    e2e_remote "CONTEXT=$(printf '%q' "${E2E_NAME}") GIT_URL=$(printf '%q' "${E2E_GIT_URL}") GIT_REF=$(printf '%q' "${E2E_GIT_REF}") bash /root/.e2e_remote_bootstrap.sh"
}

phase_rootconfig() {
    if [[ "${E2E_RESET_ENV}" == "true" ]]; then
        echo "Resetting remote .env files (--reset-env) ..."
        local projects="traefik acme-dns ${E2E_APPS//,/ }"
        local p
        local rm_cmd="rm -f .env_${E2E_NAME}"
        for p in ${projects}; do
            rm_cmd+=" ${p}/.env_${E2E_NAME}_* ${p}/docker-compose.override_${E2E_NAME}_*.yaml"
        done
        e2e_remote_sh "${rm_cmd}"
    fi
    ## Root context config: config-dist + reconfigure only. Never `make config`
    ## and never YES=yes (which would auto-answer yes to the proxy-protocol
    ## and cleartext-passwords questions):
    e2e_remote_sh "test -f .env_${E2E_NAME} || make -C . config-dist"
    e2e_make . reconfigure "var=ROOT_DOMAIN=${E2E_ROOT_DOMAIN}"
    e2e_make . dotenv_get var=ROOT_DOMAIN
}

phase_acme_dns() {
    e2e_remote_sh "test -f acme-dns/.env_${E2E_NAME}_default || make -C acme-dns config-dist instance=default"
    e2e_remote_sh "_scripts/batch-reconfigure acme-dns/.env_${E2E_NAME}_default \
ACME_DNS_SUBDOMAIN=acme-dns.${E2E_ROOT_DOMAIN} \
ACME_DNS_LISTEN_IP_ADDRESS=${DROPLET_IP} \
ACME_DNS_PUBLIC_IP_ADDRESS=${DROPLET_IP} \
ACME_DNS_HOSTMASTER=hostmaster@${E2E_DOMAIN}"
    e2e_make acme-dns override
    e2e_make acme-dns install "TIMEOUT=${E2E_TIMEOUT}"

    echo "Checking acme-dns DNS service directly (@${DROPLET_IP}) ..."
    local deadline=$((SECONDS + E2E_TIMEOUT))
    until [[ -n "$(dig +short +time=3 +tries=1 "@${DROPLET_IP}" "auth.acme-dns.${E2E_ROOT_DOMAIN}" A)" ]]; do
        (( SECONDS < deadline )) || fault "acme-dns did not answer DNS queries on ${DROPLET_IP}:53."
        sleep 5
    done
    echo "acme-dns answers DNS queries."

    ## acme-dns fetches its own (production) Let's Encrypt certificate for the
    ## API port on first boot; this requires the NS delegation to be visible
    ## to Let's Encrypt, so allow for DNS propagation:
    echo "Waiting for the acme-dns API to serve a valid certificate on :2890 ..."
    deadline=$((SECONDS + E2E_CERT_TIMEOUT))
    local code
    while :; do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
                    "https://acme-dns.${E2E_ROOT_DOMAIN}:2890/health" || true)
        [[ -n "${code}" && "${code}" != "000" ]] && break
        (( SECONDS < deadline )) || {
            e2e_make acme-dns logs-out || true
            fault "acme-dns API is not serving valid TLS on port 2890."
        }
        sleep 10
    done
    echo "acme-dns API is up (HTTP ${code})."
}

phase_traefik() {
    e2e_remote_sh "test -f traefik/.env_${E2E_NAME}_default || make -C traefik config-dist instance=default"
    e2e_make traefik traefik-user
    local cert_domains="[[\"${E2E_ROOT_DOMAIN}\",[\"*.${E2E_ROOT_DOMAIN}\"]]]"
    e2e_remote_sh "_scripts/batch-reconfigure traefik/.env_${E2E_NAME}_default \
TRAEFIK_ROOT_DOMAIN=${E2E_ROOT_DOMAIN} \
TRAEFIK_ACME_ENABLED=false \
TRAEFIK_ACME_CHALLENGE=dns \
TRAEFIK_ACME_SH_ENABLED=true \
TRAEFIK_ACME_SH_ACME_CA=${E2E_ACME_CA} \
TRAEFIK_ACME_SH_ACME_DIRECTORY=/directory \
TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE=true \
TRAEFIK_ACME_SH_ACME_DNS_BASE_URL=https://acme-dns.${E2E_ROOT_DOMAIN}:2890 \
TRAEFIK_ACME_SH_DNS_RESOLVER=1.1.1.1 \
TRAEFIK_DOCKER_COMPOSE_PROFILES=default,error_pages,acme-sh \
$(printf '%q' "TRAEFIK_ACME_CERT_DOMAINS=${cert_domains}")"
    e2e_make traefik install

    echo "Registering with acme-dns and creating _acme-challenge CNAMEs ..."
    local reg_out
    reg_out=$(e2e_make traefik acme-sh-register)
    echo "${reg_out}"
    local fqdn target rname
    while read -r fqdn _ target; do
        [[ -z "${fqdn}" || -z "${target}" ]] && continue
        rname="${fqdn%.}"
        rname="${rname%."${E2E_DOMAIN}"}"
        rname="${rname%.}"
        e2e_dns_record CNAME "${rname}" "${target%.}."
    done < <(grep -P '^\s*_acme-challenge\.' <<< "${reg_out}" | awk '{print $1, $2, $3}' | sort -u)

    e2e_make traefik restart service=acme-sh

    echo "Waiting for the wildcard certificate (*.${E2E_ROOT_DOMAIN}, CA=${E2E_ACME_CA}) ..."
    local deadline=$((SECONDS + E2E_CERT_TIMEOUT))
    local probe_host="whoami.${E2E_ROOT_DOMAIN}"
    local info="" tick=0
    while :; do
        info=$(tls_probe "${probe_host}" || true)
        if grep -q "${E2E_ROOT_DOMAIN}" <<< "${info}"; then
            echo "Certificate is live:"
            echo "${info}"
            if [[ "${E2E_ACME_CA}" == *staging* ]] && ! grep -qi "staging" <<< "${info}"; then
                echo "WARNING: expected a STAGING issuer but got the above."
            fi
            return 0
        fi
        (( SECONDS < deadline )) || {
            e2e_remote_sh "make -C traefik logs-out service=acme-sh | tail -n 80" || true
            fault "Timed out waiting for the TLS certificate (still serving: ${info:-nothing})."
        }
        tick=$((tick + 1))
        if (( tick % 4 == 0 )); then
            e2e_remote_sh "make -C traefik logs-out service=acme-sh | grep -E 'Cert success|Requesting certificate|invalid|error' | tail -n 5" || true
        fi
        sleep 10
    done
}

install_app() {
    local app="$1"
    local host="${app}.${E2E_ROOT_DOMAIN}"
    e2e_remote_sh "prefix=\$(grep -oP '^# PREFIX=\\K.*' ${app}/.env-dist)
test -n \"\${prefix}\" || { echo \"ERROR: no # PREFIX= META in ${app}/.env-dist\"; exit 1; }
test -f ${app}/.env_${E2E_NAME}_default || make -C ${app} config-dist instance=default
make -C ${app} reconfigure var=\${prefix}_TRAEFIK_HOST=${host} instance=default
make -C ${app} override instance=default
make -C ${app} install instance=default
make -C ${app} wait TIMEOUT=${E2E_TIMEOUT} instance=default"
}

phase_apps() {
    local app
    for app in ${E2E_APPS//,/ }; do
        banner "app: ${app}"
        if install_app "${app}"; then
            echo "${app}: installed and healthy."
        else
            FAILED_APPS+=("${app}")
            echo "${app}: FAILED to install."
            e2e_remote_sh "make -C ${app} status FORMAT=json; make -C ${app} logs-out 2>/dev/null | tail -n 50" || true
            if [[ "${E2E_KEEP_GOING}" != "true" ]]; then
                fault "App '${app}' failed (use --keep-going to continue past failures)."
            fi
        fi
    done
}

verify_app() {
    local app="$1"
    local host="${app}.${E2E_ROOT_DOMAIN}"
    local url="https://${host}/"
    local curl_args=(-s -o /dev/null -w '%{http_code}' --max-time 20)
    ## Staging CA is not in the system trust store; production must validate:
    [[ "${E2E_ACME_CA}" == *staging* ]] && curl_args+=(-k)
    local code info issuer status
    code=$(curl "${curl_args[@]}" "${url}" || true)
    info=$(tls_probe "${host}" || true)
    issuer=$(grep -oP '^issuer=\K.*' <<< "${info}" | head -n 1)
    status=FAIL
    if [[ "${code}" == "200" ]] && grep -q "${E2E_ROOT_DOMAIN}" <<< "${info}"; then
        if [[ "${E2E_ACME_CA}" == *staging* ]]; then
            grep -qi "staging" <<< "${info}" && status=PASS
        else
            status=PASS
        fi
    fi
    RESULTS+=("${status}|${app}|${url}|${code}|${issuer:-no-cert}")
    [[ "${status}" == "PASS" ]]
}

phase_verify() {
    local app
    for app in ${E2E_APPS//,/ }; do
        if verify_app "${app}"; then
            echo "PASS ${app}"
        else
            echo "FAIL ${app}"
        fi
    done
    return 0
}

phase_summary() {
    banner "e2e summary"
    echo "name=${E2E_NAME} root_domain=${E2E_ROOT_DOMAIN} ip=${DROPLET_IP} ca=${E2E_ACME_CA}"
    echo ""
    local row all_pass=true
    printf '%-6s %-14s %-50s %-6s %s\n' STATUS APP URL CODE ISSUER
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r st app url code issuer <<< "${row}"
        printf '%-6s %-14s %-50s %-6s %s\n' "${st}" "${app}" "${url}" "${code}" "${issuer}"
        [[ "${st}" == "PASS" ]] || all_pass=false
    done
    [[ ${#FAILED_APPS[@]} -gt 0 ]] && {
        echo "Apps that failed to install: ${FAILED_APPS[*]}"
        all_pass=false
    }
    echo ""
    echo "The droplet is KEPT (it is now a usable sworkstation):"
    echo "  ssh root@${DROPLET_IP}   (or: ssh ${E2E_NAME})"
    echo "Tear down everything with:"
    echo "  $0 destroy --name ${E2E_NAME} --yes"
    [[ -n "${LOG_FILE}" ]] && echo "Full log: ${LOG_FILE}"
    if [[ "${all_pass}" != "true" ]]; then
        echo ""
        echo "RESULT: FAIL (one or more apps failed verification)"
        exit 2
    fi
    echo ""
    echo "RESULT: PASS"
}

## -------------------------------------------------------------------------
## Commands
## -------------------------------------------------------------------------

run_phase() {
    CURRENT_PHASE="$1"
    banner "phase: $1"
    local func="phase_${1//-/_}"
    "${func}"
    mark_phase_done "$1"
}

cmd_up() {
    setup_logging
    local p
    for p in "${PHASES[@]}"; do
        run_phase "${p}"
    done
}

cmd_phase() {
    [[ -n "${E2E_PHASE}" ]] || usage 1
    local valid=false p
    for p in "${PHASES[@]}"; do
        [[ "${p}" == "${E2E_PHASE}" ]] && valid=true
    done
    [[ "${valid}" == "true" ]] || fault "Unknown phase '${E2E_PHASE}'. Valid: ${PHASES[*]}"
    setup_logging
    run_phase "${E2E_PHASE}"
}

cmd_status() {
    echo "## State file: $(state_file)"
    if [[ -f "$(state_file)" ]]; then
        cat "$(state_file)"
    else
        echo "(no state file)"
    fi
    echo ""
    echo "## Droplet:"
    doctl compute droplet list --tag-name "${E2E_NAME}" \
          --format ID,Name,PublicIPv4,Status,Region 2>/dev/null || true
    echo ""
    echo "## Latest log:"
    ls -1t "${LOG_DIR}/${E2E_NAME}-"*.log 2>/dev/null | head -n 1 || echo "(none)"
}

cmd_destroy() {
    CURRENT_PHASE="destroy"
    ## Confirm on the real terminal BEFORE logging redirects stdout/stderr
    ## through tee (a TUI prompt and the tee pipe fight over the terminal):
    echo "This will destroy ALL resources named/tagged '${E2E_NAME}':"
    echo "  - droplet, firewall '${E2E_NAME}-fw', SSH key '${E2E_NAME}'"
    if [[ -n "${E2E_SUBDOMAIN}" ]]; then
        echo "  - DNS records: ${E2E_SUBDOMAIN}, *.${E2E_SUBDOMAIN}, acme-dns.${E2E_SUBDOMAIN}, auth.acme-dns.${E2E_SUBDOMAIN}, _acme-challenge.${E2E_SUBDOMAIN} (in ${E2E_DOMAIN})"
    fi
    if [[ "${E2E_YES}" != "true" ]]; then
        if [[ -t 0 ]]; then
            local reply=""
            read -r -p "Do you really want to destroy '${E2E_NAME}'? (y/N) " reply
            [[ "${reply}" =~ ^[Yy] ]] || { echo "Cancelled."; exit 0; }
        else
            fault "Refusing to destroy non-interactively without --yes."
        fi
    fi
    setup_logging

    ## Droplet(s) by tag, then by exact name:
    local ids id
    ids=$(doctl compute droplet list --tag-name "${E2E_NAME}" --format ID --no-header || true)
    if [[ -z "${ids}" ]]; then
        ids=$(doctl compute droplet list --format ID,Name --no-header \
                  | awk -v n="${E2E_NAME}" '$2==n {print $1}')
    fi
    for id in ${ids}; do
        echo "Deleting droplet ${id} ..."
        doctl compute droplet delete "${id}" --force
    done

    ## Firewall by exact name:
    id=$(doctl compute firewall list --format ID,Name --no-header \
             | awk -v n="${E2E_NAME}-fw" '$2==n {print $1; exit}')
    if [[ -n "${id}" ]]; then
        echo "Deleting firewall ${id} ..."
        doctl compute firewall delete "${id}" --force
    fi

    ## SSH key by exact name:
    id=$(doctl compute ssh-key list --format ID,Name --no-header \
             | awk -v n="${E2E_NAME}" '$2==n {print $1; exit}')
    if [[ -n "${id}" ]]; then
        echo "Deleting SSH key ${id} ..."
        doctl compute ssh-key delete "${id}" --force
    fi

    ## DNS records - stored IDs first, then a strict name sweep:
    if [[ -n "${E2E_DOMAIN}" ]]; then
        local rec
        for id in ${DNS_RECORD_IDS//,/ }; do
            echo "Deleting DNS record ${id} ..."
            doctl compute domain records delete "${E2E_DOMAIN}" "${id}" --force 2>/dev/null || true
        done
        if [[ -n "${E2E_SUBDOMAIN}" ]]; then
            for rec in "${E2E_SUBDOMAIN}" "*.${E2E_SUBDOMAIN}" \
                       "acme-dns.${E2E_SUBDOMAIN}" "auth.acme-dns.${E2E_SUBDOMAIN}" \
                       "_acme-challenge.${E2E_SUBDOMAIN}"; do
                for id in $(doctl compute domain records list "${E2E_DOMAIN}" \
                                --format ID,Name --no-header \
                                | awk -v n="${rec}" '$2==n {print $1}'); do
                    echo "Deleting DNS record ${id} (${rec}) ..."
                    doctl compute domain records delete "${E2E_DOMAIN}" "${id}" --force
                done
            done
        fi
    else
        echo "WARNING: domain unknown (no state/--domain); skipping DNS cleanup."
    fi

    ## Local cleanup:
    if [[ -f "${HOME}/.ssh/config" ]]; then
        sed -i "/^Host ${E2E_NAME}$/,/^Host /{ /^Host ${E2E_NAME}$/d; "'/^Host /!d }' "${HOME}/.ssh/config"
    fi
    rm -f "$(state_file)"
    echo "Destroyed '${E2E_NAME}'."
}

## -------------------------------------------------------------------------
## Argument parsing and dispatch
## -------------------------------------------------------------------------

main() {
    local command=""
    E2E_PHASE=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            up|status|destroy|help) command="$1" ;;
            phase) command="phase"; E2E_PHASE="${2:-}"; shift ;;
            --token) export DIGITALOCEAN_ACCESS_TOKEN="$2"; shift ;;
            --domain) E2E_DOMAIN="$2"; shift ;;
            --subdomain) E2E_SUBDOMAIN="$2"; shift ;;
            --name) E2E_NAME="$2"; shift ;;
            --region) E2E_REGION="$2"; shift ;;
            --size) E2E_SIZE="$2"; shift ;;
            --image) E2E_IMAGE="$2"; shift ;;
            --staging) E2E_ACME_CA="acme-staging-v02.api.letsencrypt.org" ;;
            --production) E2E_ACME_CA="acme-v02.api.letsencrypt.org" ;;
            --apps) E2E_APPS="$2"; shift ;;
            --git-url) E2E_GIT_URL="$2"; shift ;;
            --git-ref) E2E_GIT_REF="$2"; shift ;;
            --timeout) E2E_TIMEOUT="$2"; shift ;;
            --ssh-pubkey) E2E_SSH_PUBKEY="$2"; shift ;;
            --keep-going) E2E_KEEP_GOING=true ;;
            --reset-env) E2E_RESET_ENV=true ;;
            --yes) E2E_YES=true ;;
            -h|--help) usage 0 ;;
            *) error "Unknown argument: $1"; usage 1 ;;
        esac
        shift
    done
    [[ -z "${command}" ]] && usage 1
    [[ "${command}" == "help" ]] && usage 0

    ## Normalize: accept a fully-qualified --subdomain (strip the domain):
    if [[ -n "${E2E_DOMAIN}" && -n "${E2E_SUBDOMAIN}" ]]; then
        if [[ "${E2E_SUBDOMAIN}" == *".${E2E_DOMAIN}" ]]; then
            E2E_SUBDOMAIN="${E2E_SUBDOMAIN%".${E2E_DOMAIN}"}"
            echo "NOTE: --subdomain included --domain; using subdomain '${E2E_SUBDOMAIN}'."
        fi
        [[ "${E2E_SUBDOMAIN}" != "${E2E_DOMAIN}" ]] \
            || fault "--subdomain must be a subdomain of --domain, not the domain itself."
    fi

    ## Resolve the instance name, then merge saved state under CLI flags:
    if [[ -z "${E2E_NAME}" ]]; then
        [[ -n "${E2E_SUBDOMAIN}" ]] || fault "Either --name or --subdomain is required."
        ## Droplet names, firewall names, and DO tags must stay in a common
        ## safe charset (DO tags do not allow dots):
        E2E_NAME="e2e-${E2E_SUBDOMAIN//./-}"
    fi
    load_state

    case "${command}" in
        up|phase)
            [[ -n "${E2E_DOMAIN}" ]] || fault "--domain is required."
            [[ -n "${E2E_SUBDOMAIN}" ]] || fault "--subdomain is required."
            ## Droplet names, firewall names, and DO tags share this name, so
            ## it must stay in the common safe charset (DO tags forbid dots).
            ## (destroy/status skip this check so they can clean up anything.)
            [[ "${E2E_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] \
                || fault "--name '${E2E_NAME}' is invalid: use only letters, digits, and dashes."
            ;;
    esac
    E2E_ROOT_DOMAIN="${E2E_SUBDOMAIN}.${E2E_DOMAIN}"
    export GUMDROP_TAG="${E2E_NAME}"

    trap 'on_error $? "${BASH_COMMAND}" ${LINENO}' ERR
    trap on_exit EXIT

    case "${command}" in
        up) cmd_up ;;
        phase) cmd_phase ;;
        status) cmd_status ;;
        destroy) cmd_destroy ;;
        help) usage 0 ;;
    esac
}

main "$@"
