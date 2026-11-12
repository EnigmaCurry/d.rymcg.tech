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
## Authenticate doctl first (one-time): `doctl auth init`. This script uses
## whatever DigitalOcean account doctl is logged into.
##
## Each test is a named config. Configure it once (interactive wizard), then
## run it; all settings come from the config file, not command-line args.
##
## Usage:
##   _e2e/e2e.sh make <NAME> config         # wizard -> <NAME>.conf (menu if it exists)
##   _e2e/e2e.sh make <NAME> full           # run the full install suite
##   _e2e/e2e.sh make <NAME> workstation    # run the workstation suite
##   _e2e/e2e.sh make <NAME> status
##   _e2e/e2e.sh make <NAME> destroy        # tear down DO resources
##   _e2e/e2e.sh make <NAME> purge          # destroy + delete the local config
##   _e2e/e2e.sh list                       # list configured tests
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
E2E_ADMIN_USER="${E2E_ADMIN_USER:-admin}"
E2E_SUITE="${E2E_SUITE:-full}"
## Comma-separated CIDRs allowed to reach the apps (full suite), written into
## every app's <PREFIX>_*SOURCERANGE (Traefik ipallowlist). Blank means "this
## machine's public IP" (from ifconfig.me), detected at run time:
E2E_IP_SOURCERANGE="${E2E_IP_SOURCERANGE:-}"
E2E_KEEP_GOING=false
E2E_REINSTALL=false
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
## Workstation files (repo, ~/.config, ~/.ssh, docker CLI config) live under
## the admin user's home; $HOME resolves to /home/${E2E_ADMIN_USER} when the
## command runs as admin:
REMOTE_REPO='$HOME/git/vendor/enigmacurry/d.rymcg.tech'
## Phase lists per suite:
##  full        - provision a server + DNS + Traefik + acme-dns + apps (the
##                complete d.rymcg.tech install, verified over HTTPS).
##  workstation - set up only the workstation tooling (docker CLI, not the
##                docker server; no DNS, no firewall, no apps).
PHASES_FULL=(preflight provision dns bootstrap rootconfig acme-dns traefik apps verify summary)
PHASES_WORKSTATION=(preflight provision bootstrap verify summary)
RESULTS=()
FAILED_APPS=()

suite_phases() {
    if [[ "${E2E_SUITE}" == "workstation" ]]; then
        printf '%s\n' "${PHASES_WORKSTATION[@]}"
    else
        printf '%s\n' "${PHASES_FULL[@]}"
    fi
}

usage() {
    cat <<EOF
e2e.sh - end-to-end smoke test / installer for d.rymcg.tech on DigitalOcean

Each test is a NAMED config. Configure it once (interactive), then run it.
All settings come from the config file; only a few runtime options are flags.

Usage: e2e.sh make <NAME> <action> [options]
       e2e.sh list

Actions:
  config        Interactive wizard; writes the config for <NAME>
  full          Run the full install suite:
                ${PHASES_FULL[*]}
  workstation   Run the workstation-only suite (docker CLI, no server/DNS):
                ${PHASES_WORKSTATION[*]}
  status        Show config, state, and droplet status
  phase NAME    Run a single phase of the configured suite
  destroy       Tear down the droplet, firewall, SSH key, and DNS records
  purge         destroy, then delete the local config/state/logs

Runtime options (override the config for this run):
  --apps LIST    Comma-separated app list (full suite)
  --timeout SECS Per-wait timeout (default: ${E2E_TIMEOUT})
  --keep-going   Continue installing apps after one fails
  --reinstall    Reinstall apps even if they already verify (apps phase)
  --reset-env    Delete the remote .env files before configuring
  --yes          Skip confirmation prompts (destroy/purge)

Examples:
  d e2e make myapp config        # configure a new test (interactive)
  d e2e make myapp full          # provision + install the full stack
  d e2e make desk workstation    # set up a workstation-only test
  d e2e make myapp destroy       # tear down the DigitalOcean resources
  d e2e list                     # list configured tests

Authentication: run 'doctl auth init' first; this script uses whatever
DigitalOcean account doctl is logged into.

Docs: https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/_e2e/README.md
EOF
    exit "${1:-0}"
}

## -------------------------------------------------------------------------
## Config file (settings, written by the wizard) and state file (resource IDs)
## -------------------------------------------------------------------------

config_file() { echo "${CONFIG_DIR}/${E2E_NAME}.conf"; }
state_file()  { echo "${CONFIG_DIR}/${E2E_NAME}.state"; }

save_config() {
    mkdir -p "${CONFIG_DIR}"
    local f
    f=$(config_file)
    cat > "${f}" <<EOF
## e2e config for '${E2E_NAME}'
## Written by: e2e.sh make ${E2E_NAME} config  (edit by hand or re-run config)
E2E_SUITE=${E2E_SUITE}
E2E_DOMAIN=${E2E_DOMAIN}
E2E_SUBDOMAIN=${E2E_SUBDOMAIN}
E2E_REGION=${E2E_REGION}
E2E_SIZE=${E2E_SIZE}
E2E_IMAGE=${E2E_IMAGE}
E2E_ACME_CA=${E2E_ACME_CA}
E2E_GIT_URL=${E2E_GIT_URL}
E2E_GIT_REF=${E2E_GIT_REF}
E2E_SSH_PUBKEY=${E2E_SSH_PUBKEY}
E2E_ADMIN_USER=${E2E_ADMIN_USER}
E2E_APPS=${E2E_APPS}
E2E_IP_SOURCERANGE=${E2E_IP_SOURCERANGE}
EOF
    chmod 600 "${f}"
}

my_public_ip() {
    ## This machine's public IPv4 address, as seen from the internet:
    curl -4 -s --max-time 10 https://ifconfig.me || true
}

normalize_cidr_list() {
    ## normalize_cidr_list "a, b/24,..." - validate a comma-separated list of
    ## IPv4/IPv6 addresses or CIDRs; print it comma-separated and normalized
    ## (bare addresses get /32 or /128). Returns 1 on any invalid entry:
    local list="${1// /}" entry addr prefix max o out=""
    [[ -n "${list}" ]] || return 1
    for entry in ${list//,/ }; do
        addr="${entry%%/*}"
        if [[ "${addr}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            for o in ${addr//./ }; do (( 10#${o} <= 255 )) || return 1; done
            max=32
        elif [[ "${addr}" == *:* && "${addr}" =~ ^[0-9a-fA-F:]+$ ]]; then
            max=128
        else
            return 1
        fi
        if [[ "${entry}" == */* ]]; then
            prefix="${entry##*/}"
            [[ "${prefix}" =~ ^[0-9]+$ ]] && (( 10#${prefix} <= max )) || return 1
        else
            prefix="${max}"
        fi
        out+="${out:+,}${addr}/${prefix}"
    done
    [[ -n "${out}" ]] || return 1
    echo "${out}"
}

app_source_range() {
    ## The effective app source range: the configured one, or this machine's
    ## public IP if none is configured (e.g. a config from before the setting):
    if [[ -n "${E2E_IP_SOURCERANGE}" ]]; then
        normalize_cidr_list "${E2E_IP_SOURCERANGE}" \
            || fault "Invalid E2E_IP_SOURCERANGE: ${E2E_IP_SOURCERANGE}"
        return 0
    fi
    local ip
    ip=$(my_public_ip)
    [[ -n "${ip}" ]] || fault "E2E_IP_SOURCERANGE is unset and ifconfig.me is unreachable; set it with: $0 make ${E2E_NAME} config"
    echo "WARNING: E2E_IP_SOURCERANGE is unset; limiting apps to ${ip}/32 (set it with: $0 make ${E2E_NAME} config)." >&2
    echo "${ip}/32"
}

## Load the config into E2E_* variables. Fault with guidance if it is missing
## (unless soft=1, used by destroy/purge/status so they work on a broken test):
load_config() {
    local soft="${1:-}"
    local f
    f=$(config_file)
    if [[ ! -f "${f}" ]]; then
        [[ -n "${soft}" ]] && return 0
        fault "No config for '${E2E_NAME}'. Create it with:  $0 make ${E2E_NAME} config"
    fi
    # shellcheck source=/dev/null
    source "${f}"
}

save_state() {
    mkdir -p "${CONFIG_DIR}"
    local f
    f=$(state_file)
    cat > "${f}" <<EOF
## e2e runtime state for '${E2E_NAME}' (resource IDs; do not store secrets)
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
    [[ -f "$(state_file)" ]] || return 0
    DROPLET_ID=$(state_get DROPLET_ID)
    DROPLET_IP=$(state_get DROPLET_IP)
    FIREWALL_ID=$(state_get FIREWALL_ID)
    SSH_KEY_ID=$(state_get SSH_KEY_ID)
    DNS_RECORD_IDS=$(state_get DNS_RECORD_IDS)
    PHASES_DONE=$(state_get PHASES_DONE)
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
    echo "##  Resume     : $0 make ${E2E_NAME} ${E2E_SUITE}   (phases are idempotent)"
    echo "##  One phase  : $0 make ${E2E_NAME} phase ${CURRENT_PHASE:-NAME}"
    echo "##  Tear down  : $0 make ${E2E_NAME} destroy --yes"
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
            e2e_remote_root "cloud-init status; tail -n 50 /var/log/cloud-init-output.log" || true
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

e2e_ssh() {
    ## e2e_ssh <user> <command...> - run a command on the droplet as <user>.
    ## stdin is /dev/null, so every d.rymcg.tech `confirm` prompt takes its
    ## non-TTY auto-yes path.
    ##
    ## Retry on ssh exit 255 (connection-level failure: KEX reset, connection
    ## closed/refused). Such failures happen BEFORE the remote command runs, so
    ## retrying is safe. A fresh droplet's sshd can transiently reset
    ## connections while it settles; back off and try again:
    local user="$1"; shift
    echo "+ [remote:${user}] $*" >&2
    local attempt rc
    for attempt in 1 2 3 4 5 6; do
        rc=0
        ## '|| rc=$?' keeps the ssh failure from tripping `set -e` here, so the
        ## retry loop always runs regardless of how this was called:
        ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
            -o ConnectTimeout=20 "${user}@${DROPLET_IP}" "$@" < /dev/null || rc=$?
        [[ ${rc} -ne 255 ]] && return ${rc}
        [[ ${attempt} -eq 6 ]] && return 255
        echo "## [retry] ssh connection failed (exit 255); attempt ${attempt}/6, backing off $((attempt * 4))s ..." >&2
        sleep $((attempt * 4))
    done
}

e2e_remote() {
    ## Run a command on the droplet as the admin workstation user:
    e2e_ssh "${E2E_ADMIN_USER}" "$@"
}

e2e_remote_root() {
    ## Run a command on the droplet as root (provision-level infra tasks):
    e2e_ssh root "$@"
}

e2e_remote_sh() {
    ## Run a shell snippet as admin inside the repo dir with the e2e docker
    ## context selected:
    ## The ERR trap names the failing command, so a set -e abort is never
    ## silent:
    e2e_remote "set -eo pipefail
trap 'echo \"ERROR: remote command failed (exit \$?): \$BASH_COMMAND\" >&2' ERR
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
    ## tls_probe <hostname> [port] - print the certificate subject+issuer
    ## served for <hostname> (port defaults to 443):
    echo | timeout 15 openssl s_client -connect "${DROPLET_IP}:${2:-443}" \
                 -servername "$1" 2>/dev/null \
        | openssl x509 -noout -subject -issuer 2>/dev/null
}

## -------------------------------------------------------------------------
## Phases
## -------------------------------------------------------------------------

phase_preflight() {
    "${BIN}/check_deps" doctl ssh git jq curl awk sed openssl dig
    doctl account get > /dev/null \
        || fault "doctl is not authenticated. Run 'doctl auth init' first."
    if [[ "${E2E_SUITE}" != "workstation" ]]; then
        doctl compute domain get "${E2E_DOMAIN}" > /dev/null \
            || fault "Domain '${E2E_DOMAIN}' is not managed by this DigitalOcean account."
        ## Hosting a zone in DigitalOcean is not enough: the domain's public
        ## nameservers must actually delegate to DigitalOcean, or the records we
        ## create are never consulted and acme-dns can never get a certificate.
        local ns
        ns=$(dig +short NS "${E2E_DOMAIN}" @1.1.1.1 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [[ -n "${ns}" ]] && ! grep -q "digitalocean" <<< "${ns}"; then
            fault "Domain '${E2E_DOMAIN}' is in your DigitalOcean account, but its public
nameservers are NOT DigitalOcean's:
$(sed 's/^/    /' <<< "${ns}")
Point the domain's registrar nameservers at ns1.digitalocean.com,
ns2.digitalocean.com, ns3.digitalocean.com (then wait for propagation),
or configure a domain that is already delegated to DigitalOcean."
        fi
    fi
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
    if [[ "${E2E_SUITE}" == "workstation" ]]; then
        echo "Preflight OK: suite=workstation name=${E2E_NAME} pubkey=${E2E_SSH_PUBKEY}"
    else
        echo "Preflight OK: suite=full domain=${E2E_DOMAIN} root_domain=${E2E_ROOT_DOMAIN} name=${E2E_NAME} pubkey=${E2E_SSH_PUBKEY}"
    fi
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

    ## Firewall (full suite only; a workstation serves nothing, so it needs no
    ## inbound firewall). 22/80/443 web + 53 tcp/udp + 2890 tcp for acme-dns:
    if [[ "${E2E_SUITE}" != "workstation" ]]; then
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
    fi

    ## Droplet. Full installs the Docker server; the workstation suite installs
    ## only the Docker CLI (it controls remote servers, it is not one):
    local user_data_template="${E2E_DIR}/user_data_docker_debian.yaml"
    [[ "${E2E_SUITE}" == "workstation" ]] \
        && user_data_template="${E2E_DIR}/user_data_workstation_debian.yaml"
    DROPLET_ID=$(doctl compute droplet list --format ID,Name --no-header \
                     | awk -v n="${E2E_NAME}" '$2==n {print $1; exit}')
    if [[ -z "${DROPLET_ID}" ]]; then
        echo "Creating droplet '${E2E_NAME}' (${E2E_REGION}/${E2E_SIZE}/${E2E_IMAGE}, suite=${E2E_SUITE}) ..."
        ## Render the cloud-init: it creates the '${E2E_ADMIN_USER}' workstation
        ## user with the operator's public key, so we can ssh in as admin and
        ## run the sworkstation unprivileged. Pubkey is reduced to 'type base64'
        ## (no comment) to keep substitution safe:
        local pubkey render
        pubkey=$(awk '{print $1, $2}' "${E2E_SSH_PUBKEY}")
        render=$(mktemp)
        sed -e "s|__E2E_ADMIN_USER__|${E2E_ADMIN_USER}|g" \
            -e "s|__E2E_SSH_PUBKEY__|${pubkey}|g" \
            "${user_data_template}" > "${render}"
        DROPLET_ID=$(doctl compute droplet create "${E2E_NAME}" \
            --region "${E2E_REGION}" --size "${E2E_SIZE}" --image "${E2E_IMAGE}" \
            --ssh-keys "${SSH_KEY_ID}" --tag-names "${E2E_NAME}" \
            --user-data-file "${render}" \
            --wait --format ID --no-header)
        rm -f "${render}"
    fi
    echo "Droplet id: ${DROPLET_ID}"
    save_state
    if [[ -n "${FIREWALL_ID}" ]] \
       && ! doctl compute firewall get "${FIREWALL_ID}" --format DropletIDs --no-header \
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

    ## Wait for SSH (root is available immediately; cloud-init installs Docker
    ## and creates the admin user during boot):
    echo "Waiting for SSH on root@${DROPLET_IP} ..."
    local deadline=$((SECONDS + 300))
    until e2e_remote_root true 2>/dev/null; do
        (( SECONDS < deadline )) || fault "Timed out waiting for SSH."
        sleep 5
    done
    echo "Waiting for cloud-init to finish (creates ${E2E_ADMIN_USER}; installs $( [[ "${E2E_SUITE}" == workstation ]] && echo "Docker CLI" || echo "Docker server")) ..."
    local rc=0
    e2e_remote_root "cloud-init status --wait" || rc=$?
    ## Exit code 2 ("recoverable errors") is common on DigitalOcean images:
    if [[ "${rc}" != "0" && "${rc}" != "2" ]]; then
        e2e_remote_root "tail -n 50 /var/log/cloud-init-output.log" || true
        fault "cloud-init failed (exit ${rc})."
    fi
    if [[ "${E2E_SUITE}" != "workstation" ]]; then
        ## Verify the docker daemon is up on its unix socket:
        e2e_remote_root "docker -H unix:///var/run/docker.sock info -f '{{.ServerVersion}}'"
    else
        ## Workstation: only the CLI is expected (no server daemon):
        e2e_remote_root "docker --version"
    fi

    ## Confirm the cloud-init sshd penalty tuning actually took effect:
    echo "sshd PerSourcePenalties setting on the droplet:"
    e2e_remote_root "sshd -T 2>/dev/null | grep -i persourcepenalties || echo '(sshd -T unavailable)'" || true

    ## The DigitalOcean firewall is the real firewall; disable any host ufw:
    e2e_remote_root "ufw disable 2>/dev/null; systemctl mask ufw 2>/dev/null; true"

    ## Confirm the admin workstation user is reachable (and, for the full suite,
    ## in the docker group so it can reach the local daemon):
    echo "Waiting for the '${E2E_ADMIN_USER}' user to be ready ..."
    deadline=$((SECONDS + 120))
    if [[ "${E2E_SUITE}" == "workstation" ]]; then
        until e2e_remote true 2>/dev/null; do
            (( SECONDS < deadline )) || fault "'${E2E_ADMIN_USER}' not reachable."
            sleep 5
        done
    else
        until e2e_remote "id -nG | tr ' ' '\n' | grep -qx docker" 2>/dev/null; do
            (( SECONDS < deadline )) || fault "'${E2E_ADMIN_USER}' not reachable / not in docker group."
            sleep 5
        done
    fi
    e2e_remote "echo \"admin user ready: \$(id)\""

    ## Local ~/.ssh/config entry for operator convenience (idempotent):
    local ssh_config="${HOME}/.ssh/config"
    mkdir -p "${HOME}/.ssh"
    touch "${ssh_config}"
    chmod 600 "${ssh_config}"
    sed -i "/^Host ${E2E_NAME}$/,/^Host /{ /^Host ${E2E_NAME}$/d; "'/^Host /!d }' "${ssh_config}"
    cat <<EOF >> "${ssh_config}"

Host ${E2E_NAME}
     Hostname ${DROPLET_IP}
     User ${E2E_ADMIN_USER}
     ControlMaster auto
     ControlPersist yes
     ControlPath /tmp/ssh-%u-%r@%h:%p
EOF
    echo "Added 'Host ${E2E_NAME}' to ${ssh_config} (connects as ${E2E_ADMIN_USER})"
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
    echo "Bootstrapping sworkstation as '${E2E_ADMIN_USER}' (context=${E2E_NAME}, git=${E2E_GIT_URL} @ ${E2E_GIT_REF}) ..."
    ## Upload the script to the admin user's home, then execute it in a separate
    ## session. Do NOT use `bash -s` with the script on stdin: any stdin-reading
    ## command inside the script (e.g. ssh) would consume the rest of the script
    ## text and bash would exit 0 early, silently skipping the remaining steps:
    echo "+ [remote] upload _e2e/lib/remote_bootstrap.sh" >&2
    ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
        "${E2E_ADMIN_USER}@${DROPLET_IP}" \
        "cat > ~/.e2e_remote_bootstrap.sh" \
        < "${E2E_DIR}/lib/remote_bootstrap.sh"
    local workstation_only=false
    [[ "${E2E_SUITE}" == "workstation" ]] && workstation_only=true
    e2e_remote "CONTEXT=$(printf '%q' "${E2E_NAME}") GIT_URL=$(printf '%q' "${E2E_GIT_URL}") GIT_REF=$(printf '%q' "${E2E_GIT_REF}") CONTEXT_SSH_USER=root WORKSTATION_ONLY=${workstation_only} bash ~/.e2e_remote_bootstrap.sh"
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
    ## Pin the name to DROPLET_IP: the local resolver may still cache the
    ## previous run's droplet IP (acme-dns serves its own A record, TTL 3600):
    echo "Waiting for the acme-dns API to serve a valid certificate on :2890 ..."
    deadline=$((SECONDS + E2E_CERT_TIMEOUT))
    local code
    while :; do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
                    --resolve "acme-dns.${E2E_ROOT_DOMAIN}:2890:${DROPLET_IP}" \
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

sourcerange_snippet() {
    ## sourcerange_snippet <app> <apply|check> - remote shell code (needs
    ## \${prefix}) that sets, or checks, every <PREFIX>_*SOURCERANGE var in the
    ## app's env file to APP_SOURCERANGE. Apps doing their own ACME (TLS
    ## passthrough, e.g. caddy) stay open (0.0.0.0/0): Let's Encrypt must reach
    ## them for the TLS-ALPN-01 challenge.
    local app="$1" mode="$2" envf="${1}/.env_${E2E_NAME}_default" action
    if [[ "${mode}" == "apply" ]]; then
        action="make -C ${app} reconfigure var=\${v}=\${range} instance=default"
    else
        action="grep -qxF \"\${v}=\${range}\" ${envf} || exit 1"
    fi
    cat <<EOF
## Limit who can reach the app (Traefik ipallowlist):
range=${APP_SOURCERANGE}
if grep -q "^\${prefix}_ACME_CA=" ${app}/.env-dist; then range=0.0.0.0/0; fi
for v in \$(grep -oP "^\${prefix}_\\w*SOURCERANGE(?==)" ${app}/.env-dist || true); do
  ${action}
done
EOF
}

app_sourcerange_current() {
    ## app_sourcerange_current <app> - true if the app's env file already has
    ## the configured source range, i.e. a passing app needs no reinstall:
    local app="$1"
    e2e_remote_sh "prefix=\$(grep -oP '^# PREFIX=\\K.*' ${app}/.env-dist || true)
test -n \"\${prefix}\" && test -f ${app}/.env_${E2E_NAME}_default || exit 1
$(sourcerange_snippet "${app}" check)" >/dev/null 2>&1
}

app_entrypoints() {
    ## app_entrypoints <app> - print "NAME PORT PROTO" for each extra Traefik
    ## entrypoint (TRAEFIK_<NAME>_ENTRYPOINT_ENABLED) an app's routes use:
    case "$1" in
        inspircd) echo "IRC 6697 tcp" ;;
        soju)     echo "IRC_BOUNCER 6698 tcp" ;;
        iperf)    echo "IPERF_TCP 5201 tcp"; echo "IPERF_UDP 5201 udp" ;;
        peertube) echo "RTMP 1935 tcp" ;;
    esac
}

ensure_app_entrypoints() {
    ## ensure_app_entrypoints <app> - enable the Traefik entrypoints the app
    ## needs and open their ports in the droplet firewall:
    local app="$1" name port proto rules enabled restart=false
    local traefik_env="traefik/.env_${E2E_NAME}_default"
    while read -r name port proto; do
        [[ -z "${name}" ]] && continue
        rules=$(doctl compute firewall get "${FIREWALL_ID}" --format InboundRules --no-header)
        if ! grep -q "protocol:${proto},ports:${port}," <<< "${rules}"; then
            echo "Opening firewall ${proto}/${port} for ${app} ..."
            doctl compute firewall add-rules "${FIREWALL_ID}" \
                  --inbound-rules "protocol:${proto},ports:${port},address:0.0.0.0/0,address:::/0"
        fi
        enabled=$(e2e_remote_sh "_scripts/dotenv -f ${traefik_env} get TRAEFIK_${name}_ENTRYPOINT_ENABLED")
        if [[ "${enabled}" != "true" ]]; then
            echo "Enabling Traefik entrypoint ${name} (${proto}/${port}) for ${app} ..."
            e2e_make traefik reconfigure "var=TRAEFIK_${name}_ENTRYPOINT_ENABLED=true"
            restart=true
        fi
    done < <(app_entrypoints "${app}")
    if [[ "${restart}" == "true" ]]; then
        e2e_make traefik install
        e2e_make traefik wait "TIMEOUT=${E2E_TIMEOUT}"
    fi
}

app_test_vars() {
    ## app_test_vars <app> - print extra VAR=value settings (one per line)
    ## that an app needs to start without outside services:
    case "$1" in
        ## The default chatbot app needs an external LLM API; test with hello:
        gradio) echo "GRADIO_APP=hello" ;;
    esac
}

install_app() {
    local app="$1"
    local host="${app}.${E2E_ROOT_DOMAIN}"
    local var test_vars=""
    while read -r var; do
        [[ -n "${var}" ]] && test_vars+="make -C ${app} reconfigure var=${var} instance=default"$'\n'
    done < <(app_test_vars "${app}")
    e2e_remote_sh "prefix=\$(grep -oP '^# PREFIX=\\K.*' ${app}/.env-dist || true)
test -n \"\${prefix}\" || { echo \"ERROR: no # PREFIX= META in ${app}/.env-dist\"; exit 1; }
test -f ${app}/.env_${E2E_NAME}_default || make -C ${app} config-dist instance=default
## config-dist skips the interactive config-hook, so generate the secrets
## it would have made (reconfigure_password only fills blank values):
{ grep -oP 'reconfigure_password \\S+ \\K[A-Z0-9_]+( [0-9]+)?' ${app}/Makefile || true; } | sort -u | \\
  while read -r var len; do _scripts/reconfigure_password ${app}/.env_${E2E_NAME}_default \${var} \${len}; done
make -C ${app} reconfigure var=\${prefix}_TRAEFIK_HOST=${host} instance=default
## Apps doing their own ACME (TLS passthrough, e.g. caddy) use the test's CA:
if grep -q \"^\${prefix}_ACME_CA=\" ${app}/.env-dist; then
  make -C ${app} reconfigure var=\${prefix}_ACME_CA=${E2E_ACME_CA} instance=default
fi
$(sourcerange_snippet "${app}" apply)
## Apps that must be told the host's public IP (e.g. doh-server):
if grep -q \"^\${prefix}_PUBLIC_IP_ADDRESS=\" ${app}/.env-dist; then
  make -C ${app} reconfigure var=\${prefix}_PUBLIC_IP_ADDRESS=${DROPLET_IP} instance=default
fi
${test_vars}make -C ${app} override instance=default
make -C ${app} install instance=default
make -C ${app} wait TIMEOUT=${E2E_TIMEOUT} instance=default"
}

phase_apps() {
    local app
    APP_SOURCERANGE=$(app_source_range)
    echo "Apps are limited to source range: ${APP_SOURCERANGE}"
    for app in ${E2E_APPS//,/ }; do
        banner "app: ${app}"
        if [[ "${E2E_REINSTALL}" != "true" ]]; then
            if probe_app "${app}"; then
                if app_sourcerange_current "${app}"; then
                    echo "${app}: already verified (result ${PROBE_CODE}); skipping install (use --reinstall to force)."
                    continue
                fi
                echo "${app}: verified, but its source range differs from ${APP_SOURCERANGE}; reinstalling."
            else
                echo "${app}: not verified (result ${PROBE_CODE}, cert: ${PROBE_ISSUER:-none}); installing."
            fi
        fi
        if ensure_app_entrypoints "${app}" && install_app "${app}"; then
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

probe_target() {
    ## probe_target <app> - set PROBE_PATH (URL path, no leading /) and
    ## PROBE_HEADERS (extra curl -H args), for apps with nothing at /.
    ## PROBE_KIND is http (default) or stun (a STUN Binding request over TLS,
    ## for TURN servers behind Traefik TLS passthrough):
    PROBE_KIND=http
    PROBE_PATH=""
    PROBE_HEADERS=()
    PROBE_PORT=443
    case "$1" in
        coturn) PROBE_KIND=stun ;;
        ## IRC over TLS on their own Traefik entrypoints:
        inspircd) PROBE_KIND=irc; PROBE_PORT=6697 ;;
        soju)     PROBE_KIND=irc; PROBE_PORT=6698 ;;
        ## iperf3 is plain TCP (no TLS) on its own entrypoint:
        iperf)    PROBE_KIND=iperf; PROBE_PORT=5201 ;;
        doh-server)
            ## A DNS query for example.com/A (RFC 8484 GET, base64url wire format):
            PROBE_PATH="dns-query?dns=q80BAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE"
            PROBE_HEADERS=(-H "accept: application/dns-message") ;;
    esac
}

probe_app() {
    ## probe_app <app> - check the app's HTTPS route externally, without
    ## recording anything. Sets PROBE_STATUS/PROBE_URL/PROBE_CODE/PROBE_ISSUER
    ## and returns 0 on PASS:
    local app="$1"
    local host="${app}.${E2E_ROOT_DOMAIN}"
    probe_target "${app}"
    local info out final
    if [[ "${PROBE_KIND}" == "stun" ]]; then
        PROBE_URL="turns://${host}:443"
        ## Binding request: type 0x0001, length 0, magic cookie, 12-byte txid.
        ## Success is type 0x0101 echoing the cookie and txid:
        out=$( (printf '\x00\x01\x00\x00\x21\x12\xa4\x42e2eprobe0001'; sleep 3) \
                   | timeout 10 openssl s_client -quiet -connect "${DROPLET_IP}:443" \
                         -servername "${host}" 2>/dev/null \
                   | od -An -tx1 -N20 | tr -d ' \n' || true)
        ## 0101 <len> 2112a442 <txid "e2eprobe0001" in hex>:
        if [[ "${out}" =~ ^0101[0-9a-f]{4}2112a44265326570726f626530303031$ ]]; then
            PROBE_CODE=stun-ok
        else
            PROBE_CODE=stun-fail
        fi
    elif [[ "${PROBE_KIND}" == "irc" ]]; then
        PROBE_URL="ircs://${host}:${PROBE_PORT}"
        ## Register and expect any server reply line (":server CMD ..."):
        out=$( (printf 'NICK e2eprobe\r\nUSER e2e 0 * :e2e\r\n'; sleep 8; printf 'QUIT\r\n'; sleep 1) \
                   | timeout 15 openssl s_client -quiet -connect "${DROPLET_IP}:${PROBE_PORT}" \
                         -servername "${host}" 2>/dev/null || true)
        if grep -qE '^:[^ ]+ [A-Z0-9]+ ' <<< "${out}"; then
            PROBE_CODE=irc-ok
        else
            PROBE_CODE=irc-fail
        fi
    elif [[ "${PROBE_KIND}" == "iperf" ]]; then
        PROBE_URL="iperf3://${host}:${PROBE_PORT}"
        ## Send a 37-byte iperf3 cookie; the server answers PARAM_EXCHANGE (9):
        out=$(timeout 10 bash -c 'exec 3<>/dev/tcp/$1/$2 || exit 1
printf "%-36s\0" e2eprobe >&3; IFS= read -r -t 5 -N 1 b <&3 || exit 1; printf "%d" "'"'"'$b"' \
                  _ "${DROPLET_IP}" "${PROBE_PORT}" 2>/dev/null || true)
        if [[ "${out}" == "9" ]]; then
            PROBE_CODE=iperf-ok
        else
            PROBE_CODE=iperf-fail
        fi
    else
        PROBE_URL="https://${host}/${PROBE_PATH}"
        ## Follow redirects (many apps send / to /login or a subpath), but
        ## only count it if the final URL is still on the app's own host:
        ## Pin the host to DROPLET_IP so a stale local DNS cache (from a
        ## previous run's droplet) can't misdirect the probe:
        local curl_args=(-s -o /dev/null -w '%{http_code} %{url_effective}' --max-time 20 -L --max-redirs 5
                         --resolve "${host}:443:${DROPLET_IP}")
        ## Staging CA is not in the system trust store; production must validate:
        [[ "${E2E_ACME_CA}" == *staging* ]] && curl_args+=(-k)
        out=$(curl "${curl_args[@]}" "${PROBE_HEADERS[@]}" "${PROBE_URL}" || true)
        PROBE_CODE="${out%% *}"
        final="${out#* }"
        if [[ "${final}" != "https://${host}/"* ]]; then
            PROBE_CODE="${PROBE_CODE}->${final}"
        fi
    fi
    if [[ "${PROBE_KIND}" == "iperf" ]]; then
        ## No TLS on iperf; vouch for the host with the HTTPS cert instead:
        info=$(tls_probe "${host}" || true)
    else
        info=$(tls_probe "${host}" "${PROBE_PORT}" || true)
    fi
    PROBE_ISSUER=$(grep -oP '^issuer=\K.*' <<< "${info}" | head -n 1 || true)
    PROBE_STATUS=FAIL
    if [[ "${PROBE_CODE}" =~ ^(200|stun-ok|irc-ok|iperf-ok)$ ]] && grep -q "${E2E_ROOT_DOMAIN}" <<< "${info}"; then
        if [[ "${E2E_ACME_CA}" == *staging* ]]; then
            grep -qi "staging" <<< "${info}" && PROBE_STATUS=PASS
        else
            PROBE_STATUS=PASS
        fi
    fi
    [[ "${PROBE_STATUS}" == "PASS" ]]
}

verify_app() {
    probe_app "$1" || true
    RESULTS+=("${PROBE_STATUS}|$1|${PROBE_URL}|${PROBE_CODE}|${PROBE_ISSUER:-no-cert}")
    [[ "${PROBE_STATUS}" == "PASS" ]]
}

verify_check() {
    ## verify_check <label> <remote-command> - run a check as admin on the
    ## droplet. The command runs in the repo dir with the d.rymcg.tech CLI
    ## (_scripts/user) and uv (~/.local/bin) on PATH, and WITHOUT a forced
    ## DOCKER_CONTEXT (a workstation has no context). Captures stdout for the
    ## detail column; records PASS/FAIL into RESULTS:
    local label="$1" cmd="$2" out rc=0
    out=$(e2e_remote "cd ${REMOTE_REPO} 2>/dev/null; export PATH=\"\$PATH:\$HOME/.local/bin:${REMOTE_REPO}/_scripts/user\"; ${cmd}" 2>/dev/null) || rc=$?
    out=$(printf '%s' "${out}" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-55)
    local status=FAIL
    [[ ${rc} -eq 0 ]] && status=PASS
    RESULTS+=("${status}|${label}|${out}")
    [[ "${status}" == "PASS" ]]
}

phase_verify() {
    if [[ "${E2E_SUITE}" == "workstation" ]]; then
        ## Workstation: confirm the CLI tooling is installed and functional,
        ## and that NO docker server is running locally (CLI-only). Avoid
        ## piping into `head` (SIGPIPE would trip under pipefail); count with
        ## `wc -l` instead:
        local checks=(
            "d-cli|command -v d.rymcg.tech"
            "d-list|echo \"\$(d.rymcg.tech list --raw | wc -l) projects\""
            "docker-cli|docker --version"
            "docker-compose|docker compose version"
            "no-docker-server|! docker -H unix:///var/run/docker.sock info >/dev/null 2>&1"
            "uv|uv --version"
        )
        local entry label cmd
        for entry in "${checks[@]}"; do
            label="${entry%%|*}"; cmd="${entry#*|}"
            if verify_check "${label}" "${cmd}"; then
                echo "PASS ${label}"
            else
                echo "FAIL ${label}"
            fi
        done
        return 0
    fi
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
    banner "e2e summary (suite=${E2E_SUITE})"
    if [[ "${E2E_SUITE}" == "workstation" ]]; then
        echo "name=${E2E_NAME} ip=${DROPLET_IP}"
    else
        echo "name=${E2E_NAME} root_domain=${E2E_ROOT_DOMAIN} ip=${DROPLET_IP} ca=${E2E_ACME_CA}"
    fi
    echo ""
    local row all_pass=true
    if [[ "${E2E_SUITE}" == "workstation" ]]; then
        printf '%-6s %-18s %s\n' STATUS CHECK DETAIL
        for row in "${RESULTS[@]}"; do
            IFS='|' read -r st label detail <<< "${row}"
            printf '%-6s %-18s %s\n' "${st}" "${label}" "${detail}"
            [[ "${st}" == "PASS" ]] || all_pass=false
        done
    else
        printf '%-6s %-14s %-50s %-6s %s\n' STATUS APP URL CODE ISSUER
        for row in "${RESULTS[@]}"; do
            IFS='|' read -r st app url code issuer <<< "${row}"
            printf '%-6s %-14s %-50s %-6s %s\n' "${st}" "${app}" "${url}" "${code}" "${issuer}"
            [[ "${st}" == "PASS" ]] || all_pass=false
        done
    fi
    [[ ${#FAILED_APPS[@]} -gt 0 ]] && {
        echo "Apps that failed to install: ${FAILED_APPS[*]}"
        all_pass=false
    }
    echo ""
    echo "The droplet is KEPT (it is now a usable sworkstation):"
    echo "  ssh ${E2E_ADMIN_USER}@${DROPLET_IP}   (or: ssh ${E2E_NAME})"
    echo "Tear down everything with:"
    echo "  $0 make ${E2E_NAME} destroy --yes"
    [[ -n "${LOG_FILE}" ]] && echo "Full log: ${LOG_FILE}"
    if [[ "${all_pass}" != "true" ]]; then
        echo ""
        echo "RESULT: FAIL (one or more checks failed verification)"
        exit 2
    fi
    echo ""
    echo "RESULT: PASS"
}

## -------------------------------------------------------------------------
## Commands
## -------------------------------------------------------------------------

## Normalize derived settings after config/flags are resolved. Strips a
## fully-qualified subdomain, computes ROOT_DOMAIN, sets the DO tag, and
## validates required fields for the selected suite:
post_config_setup() {
    if [[ -n "${E2E_DOMAIN}" && -n "${E2E_SUBDOMAIN}" ]]; then
        if [[ "${E2E_SUBDOMAIN}" == *".${E2E_DOMAIN}" ]]; then
            E2E_SUBDOMAIN="${E2E_SUBDOMAIN%".${E2E_DOMAIN}"}"
        fi
    fi
    E2E_ROOT_DOMAIN="${E2E_SUBDOMAIN}.${E2E_DOMAIN}"
    export GUMDROP_TAG="${E2E_NAME}"
}

## Require the fields a run action needs; point back at 'config' on failure:
require_run_config() {
    [[ "${E2E_SUITE}" == "full" || "${E2E_SUITE}" == "workstation" ]] \
        || fault "Config for '${E2E_NAME}' has no suite. Re-run:  $0 make ${E2E_NAME} config"
    if [[ "${E2E_SUITE}" != "workstation" ]]; then
        [[ -n "${E2E_DOMAIN}" && -n "${E2E_SUBDOMAIN}" ]] \
            || fault "The full suite needs a domain and subdomain. Re-run:  $0 make ${E2E_NAME} config"
    fi
    [[ -f "${E2E_SSH_PUBKEY}" ]] \
        || fault "SSH public key '${E2E_SSH_PUBKEY}' not found. Re-run:  $0 make ${E2E_NAME} config"
}

## Select a slug from a DigitalOcean list (script-wizard menu). Labels are read
## from stdin, one per line, with the slug as the first whitespace-delimited
## field; the chosen slug is stored in the named variable. Falls back to a
## free-text prompt when the list is empty (e.g. doctl not authenticated):
_choose_slug() {
    local __var="$1" __prompt="$2" __default="$3"
    local labels=() opts=() dflt="" lbl choice
    readarray -t labels
    if [[ ${#labels[@]} -eq 0 ]]; then
        ask "${__prompt} (slug)" "${__var}" "${__default}"
        return
    fi
    for lbl in "${labels[@]}"; do
        opts+=("${lbl}")
        [[ "$(awk '{print $1}' <<< "${lbl}")" == "${__default}" ]] && dflt="${lbl}"
    done
    choice=$(wizard choose "${__prompt}" "${opts[@]}" \
        --default "${dflt:-${opts[0]}}") || fault "Config cancelled."
    printf -v "${__var}" '%s' "$(awk '{print $1}' <<< "${choice}")"
}

choose_region() {
    _choose_slug E2E_REGION "Droplet region" "${E2E_REGION:-nyc2}" \
        < <(doctl compute region list --format Slug,Name --no-header 2>/dev/null </dev/null || true)
}

choose_size() {
    _choose_slug E2E_SIZE "Droplet size (slug  vCPUs  MemMB  DiskGB  \$/mo)" \
        "${E2E_SIZE:-s-2vcpu-4gb}" \
        < <(doctl compute size list \
                --format Slug,VCPUs,Memory,Disk,PriceMonthly --no-header 2>/dev/null </dev/null || true)
}

choose_image() {
    ## list-distribution = base OS images only (not one-click app images). The
    ## bootstrap only supports Debian-based images, so filter to those:
    _choose_slug E2E_IMAGE "Droplet image (Debian/Ubuntu)" "${E2E_IMAGE:-debian-13-x64}" \
        < <(doctl compute image list-distribution --public \
                --format Slug,Distribution --no-header 2>/dev/null </dev/null \
                | grep -iE 'debian|ubuntu' | sort || true)
}

## Select the parent domain from the account's DigitalOcean-managed zones:
choose_domain() {
    local domains=() d found="" choice
    readarray -t domains < <(doctl compute domain list --format Domain --no-header 2>/dev/null </dev/null || true)
    if [[ ${#domains[@]} -eq 0 ]]; then
        ask_no_blank "Parent domain (must be managed by DigitalOcean DNS)" \
            E2E_DOMAIN "${E2E_DOMAIN}"
        return
    fi
    for d in "${domains[@]}"; do [[ "${d}" == "${E2E_DOMAIN}" ]] && found=1; done
    choice=$(wizard choose "Parent domain (DigitalOcean-managed)" "${domains[@]}" \
        --default "$( [[ -n "${found}" ]] && echo "${E2E_DOMAIN}" || echo "${domains[0]}")") \
        || fault "Config cancelled."
    E2E_DOMAIN="${choice}"
}

## Select the SSH public key to install from ~/.ssh/*.pub (with an escape to
## enter a custom path):
choose_ssh_pubkey() {
    local pubs=() opts=() f found="" choice
    local other="Other (enter a path)"
    readarray -t pubs < <(ls -1 "${HOME}"/.ssh/*.pub 2>/dev/null || true)
    if [[ ${#pubs[@]} -eq 0 ]]; then
        ask_no_blank "SSH public key to install" E2E_SSH_PUBKEY \
            "${E2E_SSH_PUBKEY:-${HOME}/.ssh/id_ed25519.pub}"
        return
    fi
    opts=("${pubs[@]}" "${other}")
    for f in "${opts[@]}"; do [[ "${f}" == "${E2E_SSH_PUBKEY}" ]] && found=1; done
    choice=$(wizard choose "SSH public key to install" "${opts[@]}" \
        --default "$( [[ -n "${found}" ]] && echo "${E2E_SSH_PUBKEY}" || echo "${pubs[0]}")") \
        || fault "Config cancelled."
    if [[ "${choice}" == "${other}" ]]; then
        ask_no_blank "Enter SSH public key path" E2E_SSH_PUBKEY \
            "${E2E_SSH_PUBKEY:-${HOME}/.ssh/id_ed25519.pub}"
    else
        E2E_SSH_PUBKEY="${choice}"
    fi
}

## Multi-select the apps to install from the repo's web projects (those with a
## *_TRAEFIK_HOST route), pre-checking the current/default selection. Stores a
## comma-separated list in E2E_APPS. Falls back to free text if none are found:
choose_apps() {
    local all_apps=() defaults=() selected=() out rc a want default_json
    readarray -t all_apps < <(
        cd "${ROOT_DIR}" 2>/dev/null || exit 0
        for d in */; do
            d="${d%/}"
            [[ -f "${d}/.env-dist" && -f "${d}/Makefile" ]] || continue
            grep -qE '_TRAEFIK_HOST=' "${d}/.env-dist" || continue
            echo "${d}"
        done | sort
    )
    if [[ ${#all_apps[@]} -eq 0 ]]; then
        ask "Apps to install (comma-separated)" E2E_APPS \
            "${E2E_APPS:-whoami,datetime,it-tools,excalidraw,privatebin}"
        return
    fi
    ## Pre-check the current (or default) apps that actually exist:
    local want_list="${E2E_APPS:-whoami,datetime,it-tools,excalidraw,privatebin}"
    for want in ${want_list//,/ }; do
        printf '%s\n' "${all_apps[@]}" | grep -qxF "${want}" && defaults+=("${want}")
    done
    default_json="["
    local first=1
    for a in "${defaults[@]}"; do
        [[ ${first} -eq 1 ]] && first=0 || default_json+=","
        default_json+="\"${a}\""
    done
    default_json+="]"

    while :; do
        rc=0
        out=$(wizard select --cancel-code=2 \
            "Select apps to install (space toggles, enter confirms)" \
            "${all_apps[@]}" --default "${default_json}") || rc=$?
        [[ ${rc} -eq 2 ]] && fault "Config cancelled."
        readarray -t selected < <(printf '%s\n' "${out}" | grep -v '^$')
        [[ ${#selected[@]} -gt 0 ]] && break
        echo "Select at least one app (press space to toggle items)."
    done
    E2E_APPS=$(IFS=,; echo "${selected[*]}")
}

choose_ip_sourcerange() {
    ## Ask which CIDRs may reach the apps. Default: this machine's public IP
    ## (the checks run from here). 0.0.0.0/0 opens them to everyone:
    local default="${E2E_IP_SOURCERANGE}" ip answer normalized
    if [[ -z "${default}" ]]; then
        ip=$(my_public_ip)
        default="${ip:+${ip}/32}"
        default="${default:-0.0.0.0/0}"
    fi
    echo ""
    echo "Each app's IP source range filter (<PREFIX>_IP_SOURCERANGE) limits who"
    echo "can reach it. The checks run from this machine, so its address must be"
    echo "included. Use 0.0.0.0/0 to make the test apps public. Apps that get"
    echo "their own certificate via TLS-ALPN (e.g. caddy) are always left open."
    while true; do
        ask "App source range (comma-separated CIDRs)" answer "${default}"
        if normalized=$(normalize_cidr_list "${answer}"); then
            E2E_IP_SOURCERANGE="${normalized}"
            break
        fi
        echo "Invalid CIDR list: '${answer}' (e.g. 203.0.113.7/32,2001:db8::/48)"
    done
}

cmd_config() {
    [[ -t 0 ]] || fault "'config' is interactive; run it in a terminal."
    ## The wizard is interactive: read/confirm/wizard legitimately return
    ## non-zero (empty input, cancel), so drop the strict ERR/-e handling that
    ## the automated phases rely on. Explicit `fault`/`|| fault` still abort.
    trap - ERR
    set +eE +o pipefail

    ## Make sure script-wizard is available for the menu prompts:
    [[ -x "${BIN}/script-wizard" ]] || "${BIN}/install_script-wizard" --yes

    ## Authenticate doctl if needed, so the region/size/image/domain pickers can
    ## query the API (otherwise they fall back to free-text prompts):
    if ! doctl account get >/dev/null 2>&1; then
        echo "doctl is not authenticated to DigitalOcean."
        if confirm yes "Run 'doctl auth init' now" "?"; then
            doctl auth init || true
        fi
        doctl account get >/dev/null 2>&1 \
            || echo "NOTE: still unauthenticated - region/size/image/domain will be free-text."
    fi

    ## A first run walks through every question; re-running on an existing
    ## config opens a menu to change individual settings instead:
    if [[ -f "$(config_file)" ]]; then
        load_config
        echo "Reconfiguring e2e test '${E2E_NAME}' ($(config_file))"
        echo ""
        config_menu
    else
        echo "Configuring e2e test '${E2E_NAME}' (written to $(config_file))"
        echo ""
        config_all
    fi

    config_normalize
    save_config
    echo ""
    echo "Wrote $(config_file)."
    echo "Run it with:  $0 make ${E2E_NAME} ${E2E_SUITE}"
}

## One function per config question (used by both the full walk-through and
## the reconfigure menu):
config_suite() {
    local suite
    suite=$(wizard choose "Which suite is this test for?" \
        full workstation --default "${E2E_SUITE:-full}") || suite=""
    [[ -n "${suite}" ]] || fault "Config cancelled."
    E2E_SUITE="${suite}"
}
config_admin_user() {
    ask "Admin (workstation) username" E2E_ADMIN_USER "${E2E_ADMIN_USER:-admin}"
}
config_git_url() {
    ask "Git remote to clone on the droplet" E2E_GIT_URL \
        "${E2E_GIT_URL:-https://github.com/EnigmaCurry/d.rymcg.tech.git}"
}
config_git_ref() {
    ask "Git ref (branch/tag/sha)" E2E_GIT_REF "${E2E_GIT_REF:-master}"
}
config_subdomain() {
    ask_no_blank "Subdomain for this test to own (under ${E2E_DOMAIN})" \
        E2E_SUBDOMAIN "${E2E_SUBDOMAIN:-${E2E_NAME}}"
}
config_acme_ca() {
    local staging="staging (for testing; untrusted certs)"
    local production="production (real trusted certs; rate-limited)"
    local ca
    ca=$(wizard choose "Let's Encrypt certificate authority" "${staging}" "${production}" \
        --default "$( [[ "${E2E_ACME_CA}" == acme-v02.* ]] && echo "${production}" || echo "${staging}")") \
        || ca=""
    [[ -n "${ca}" ]] || fault "Config cancelled."
    case "${ca}" in
        production*) E2E_ACME_CA="acme-v02.api.letsencrypt.org" ;;
        *)           E2E_ACME_CA="acme-staging-v02.api.letsencrypt.org" ;;
    esac
}

## The full-suite-only questions:
config_full_suite() {
    choose_domain
    config_subdomain
    config_acme_ca
    choose_apps
    choose_ip_sourcerange
}

## First run: ask every question in order:
config_all() {
    config_suite
    choose_region
    choose_size
    choose_image
    config_admin_user
    choose_ssh_pubkey
    config_git_url
    config_git_ref
    [[ "${E2E_SUITE}" == "full" ]] && config_full_suite
    return 0
}

## Settle settings that depend on the suite before saving:
config_normalize() {
    if [[ "${E2E_SUITE}" == "full" ]]; then
        return 0
    fi
    ## Workstation needs none of the DNS/cert/app settings:
    E2E_DOMAIN=""
    E2E_SUBDOMAIN=""
    E2E_ACME_CA="${E2E_ACME_CA:-acme-staging-v02.api.letsencrypt.org}"
}

## All saved settings on one line, to tell whether the menu changed anything:
config_snapshot() {
    local v
    for v in E2E_SUITE E2E_DOMAIN E2E_SUBDOMAIN E2E_REGION E2E_SIZE E2E_IMAGE \
             E2E_ACME_CA E2E_GIT_URL E2E_GIT_REF E2E_SSH_PUBKEY E2E_ADMIN_USER \
             E2E_APPS E2E_IP_SOURCERANGE; do
        printf '%s=%q;' "${v}" "${!v}"
    done
}

## Reconfigure: show each setting with its current value; pick one to change,
## until "Save and exit". Returns to the caller to save, or exits on discard:
config_menu() {
    local original keys=() labels=() choice i key value
    local save="Save and exit" discard="Exit without saving" walk="Walk through all questions"
    original=$(config_snapshot)
    while :; do
        ## A newly chosen full suite still needs its domain/subdomain:
        if [[ "${E2E_SUITE}" == "full" && ( -z "${E2E_DOMAIN}" || -z "${E2E_SUBDOMAIN}" ) ]]; then
            echo "The full suite needs a few more settings:"
            config_full_suite
        fi
        keys=(suite region size image admin_user ssh_pubkey git_url git_ref)
        [[ "${E2E_SUITE}" == "full" ]] && keys+=(domain subdomain acme_ca apps ip_sourcerange)
        labels=()
        for key in "${keys[@]}"; do
            case "${key}" in
                suite)          value="${E2E_SUITE}" ;;
                region)         value="${E2E_REGION}" ;;
                size)           value="${E2E_SIZE}" ;;
                image)          value="${E2E_IMAGE}" ;;
                admin_user)     value="${E2E_ADMIN_USER}" ;;
                ssh_pubkey)     value="${E2E_SSH_PUBKEY}" ;;
                git_url)        value="${E2E_GIT_URL}" ;;
                git_ref)        value="${E2E_GIT_REF}" ;;
                domain)         value="${E2E_DOMAIN}" ;;
                subdomain)      value="${E2E_SUBDOMAIN}" ;;
                acme_ca)        [[ "${E2E_ACME_CA}" == acme-v02.* ]] \
                                    && value="production" || value="staging" ;;
                apps)           value="${E2E_APPS}" ;;
                ip_sourcerange) value="${E2E_IP_SOURCERANGE}" ;;
            esac
            [[ ${#value} -gt 60 ]] && value="${value:0:57}..."
            labels+=("$(printf '%-15s %s' "${key//_/ }" "${value:-(unset)}")")
        done
        choice=$(wizard choose "Choose a setting to change ('${E2E_NAME}')" \
            "${labels[@]}" "${walk}" "${save}" "${discard}" --default "${save}") \
            || choice="${discard}"
        case "${choice}" in
            "${save}") return 0 ;;
            "${walk}") config_all; continue ;;
            "${discard}")
                if [[ "$(config_snapshot)" == "${original}" ]] \
                       || confirm no "Discard your changes" "?"; then
                    echo "No changes saved."
                    exit 0
                fi
                continue ;;
        esac
        for i in "${!labels[@]}"; do
            [[ "${labels[$i]}" == "${choice}" ]] || continue
            case "${keys[$i]}" in
                suite)          config_suite ;;
                region)         choose_region ;;
                size)           choose_size ;;
                image)          choose_image ;;
                admin_user)     config_admin_user ;;
                ssh_pubkey)     choose_ssh_pubkey ;;
                git_url)        config_git_url ;;
                git_ref)        config_git_ref ;;
                domain)         choose_domain ;;
                subdomain)      config_subdomain ;;
                acme_ca)        config_acme_ca ;;
                apps)           choose_apps ;;
                ip_sourcerange) choose_ip_sourcerange ;;
            esac
            break
        done
        echo ""
    done
}

cmd_list() {
    echo "Configured e2e tests (${CONFIG_DIR}):"
    local f name suite ran
    shopt -s nullglob
    local found=0
    for f in "${CONFIG_DIR}"/*.conf; do
        found=1
        name=$(basename "${f}" .conf)
        suite=$(grep -oP '^E2E_SUITE=\K.*' "${f}" 2>/dev/null)
        ran="no"
        [[ -f "${CONFIG_DIR}/${name}.state" ]] && ran="yes"
        printf '  %-24s suite=%-12s provisioned=%s\n' "${name}" "${suite:-?}" "${ran}"
    done
    shopt -u nullglob
    [[ ${found} -eq 0 ]] && echo "  (none - create one with: $0 make <NAME> config)"
}

run_phase() {
    CURRENT_PHASE="$1"
    banner "phase: $1"
    local func="phase_${1//-/_}"
    "${func}"
    mark_phase_done "$1"
}

cmd_run() {
    setup_logging
    local p
    while read -r p; do
        run_phase "${p}"
    done < <(suite_phases)
}

cmd_phase() {
    [[ -n "${E2E_PHASE}" ]] || usage 1
    local valid=false p
    while read -r p; do
        [[ "${p}" == "${E2E_PHASE}" ]] && valid=true
    done < <(suite_phases)
    [[ "${valid}" == "true" ]] || fault "Unknown phase '${E2E_PHASE}' for suite '${E2E_SUITE}'. Valid: $(suite_phases | tr '\n' ' ')"
    setup_logging
    run_phase "${E2E_PHASE}"
}

cmd_status() {
    echo "## Config: $(config_file)"
    if [[ -f "$(config_file)" ]]; then cat "$(config_file)"; else echo "(no config)"; fi
    echo ""
    echo "## State: $(state_file)"
    if [[ -f "$(state_file)" ]]; then cat "$(state_file)"; else echo "(not provisioned)"; fi
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

cmd_purge() {
    CURRENT_PHASE="purge"
    echo "This will DESTROY all DigitalOcean resources for '${E2E_NAME}' AND"
    echo "delete its local config, state, and logs."
    if [[ "${E2E_YES}" != "true" ]]; then
        if [[ -t 0 ]]; then
            local reply=""
            read -r -p "Purge '${E2E_NAME}'? (y/N) " reply
            [[ "${reply}" =~ ^[Yy] ]] || { echo "Cancelled."; exit 0; }
        else
            fault "Refusing to purge non-interactively without --yes."
        fi
    fi
    E2E_YES=true   ## cmd_destroy won't re-prompt
    cmd_destroy
    rm -f "$(config_file)"
    rm -f "${LOG_DIR}/${E2E_NAME}-"*.log 2>/dev/null || true
    echo "Purged '${E2E_NAME}' (config, state, and logs removed)."
}

## -------------------------------------------------------------------------
## Argument parsing and dispatch
## -------------------------------------------------------------------------

main() {
    E2E_PHASE=""
    local command="" apps_override=""

    ## Top-level: 'list' / 'help', otherwise 'make <NAME> <action> [options]':
    case "${1:-}" in
        ""|help|-h|--help) usage 0 ;;
        list)              cmd_list; exit 0 ;;
        make)              shift ;;
        *) error "Unknown command '${1}'. Use: $0 make <NAME> <action>"; usage 1 ;;
    esac

    E2E_NAME="${1:-}"
    [[ -n "${E2E_NAME}" ]] || { error "Missing <NAME>."; usage 1; }
    shift
    command="${1:-}"
    [[ -n "${command}" ]] || { error "Missing <action> for '${E2E_NAME}'."; usage 1; }
    shift
    if [[ "${command}" == "phase" ]]; then
        E2E_PHASE="${1:-}"
        [[ -n "${E2E_PHASE}" ]] || { error "'phase' needs a phase name."; usage 1; }
        shift
    fi

    ## Only a few runtime options remain as flags; everything else is config:
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --apps)       apps_override="$2"; shift ;;
            --timeout)    E2E_TIMEOUT="$2"; shift ;;
            --keep-going) E2E_KEEP_GOING=true ;;
            --reinstall)  E2E_REINSTALL=true ;;
            --reset-env)  E2E_RESET_ENV=true ;;
            --yes)        E2E_YES=true ;;
            -h|--help)    usage 0 ;;
            *) error "Unknown option: $1"; usage 1 ;;
        esac
        shift
    done

    ## NAME is used for the droplet, firewall, and DO tag; keep it safe:
    [[ "${E2E_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] \
        || fault "Invalid NAME '${E2E_NAME}': use only letters, digits, and dashes."

    trap 'on_error $? "${BASH_COMMAND}" ${LINENO}' ERR
    trap on_exit EXIT

    case "${command}" in
        config)
            cmd_config
            ;;
        full|workstation)
            load_config
            E2E_SUITE="${command}"
            [[ -n "${apps_override}" ]] && E2E_APPS="${apps_override}"
            post_config_setup
            require_run_config
            load_state
            cmd_run
            ;;
        phase)
            load_config
            [[ -n "${apps_override}" ]] && E2E_APPS="${apps_override}"
            post_config_setup
            require_run_config
            load_state
            cmd_phase
            ;;
        status)
            load_config soft
            post_config_setup
            load_state
            cmd_status
            ;;
        destroy)
            load_config soft
            post_config_setup
            load_state
            cmd_destroy
            ;;
        purge)
            load_config soft
            post_config_setup
            load_state
            cmd_purge
            ;;
        *)
            error "Unknown action '${command}'."
            usage 1
            ;;
    esac
}

main "$@"
