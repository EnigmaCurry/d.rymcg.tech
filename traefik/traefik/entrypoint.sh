#!/bin/sh
set -e

CONFIG=/data/config/traefik.yml
RESTART_FLAG=/data/restart_me
RESTART_DELAY=10

log() { printf '%s\n' "$*"; }

# --- Create traefik user/groups at runtime from env vars ---
: "${TRAEFIK_UID:=61524}"
: "${TRAEFIK_GID:=61524}"
: "${TRAEFIK_DOCKER_GID:=999}"

if ! getent group "$TRAEFIK_GID" >/dev/null 2>&1; then
    addgroup -g "$TRAEFIK_GID" traefik
fi
TRAEFIK_GROUP="$(getent group "$TRAEFIK_GID" | cut -d: -f1)"

if ! getent group "$TRAEFIK_DOCKER_GID" >/dev/null 2>&1; then
    addgroup -g "$TRAEFIK_DOCKER_GID" docker
fi
DOCKER_GROUP="$(getent group "$TRAEFIK_DOCKER_GID" | cut -d: -f1)"

if ! getent passwd "$TRAEFIK_UID" >/dev/null 2>&1; then
    adduser traefik -D -u "$TRAEFIK_UID" -G "$TRAEFIK_GROUP"
fi
TRAEFIK_USER="$(getent passwd "$TRAEFIK_UID" | cut -d: -f1)"

addgroup "$TRAEFIK_USER" "$DOCKER_GROUP" 2>/dev/null || true

chown "$TRAEFIK_UID:$TRAEFIK_GID" /data

# --- Bootstrap Step-CA (get root cert + derive intermediate) ---
: "${STEP_CA_ENABLED:=false}"
export STEPPATH=/certs/step
STEP_CA_FINGERPRINT_FILE=/data/.step_ca_fingerprint
## Set when the bootstrap must be retried after Traefik starts:
STEP_CA_PENDING=false

step_ca_bootstrap() {
    ## Fetch the root (verified by fingerprint) and derive the intermediate.
    ## Writes nothing permanent unless every step succeeds:
    step ca bootstrap --ca-url "${STEP_CA_ENDPOINT}" --install --force --fingerprint "${STEP_CA_FINGERPRINT}" || return 1
    step ca roots > /certs/step_ca_root.crt.tmp || return 1
    step certificate inspect "${STEP_CA_ENDPOINT}" --roots /certs/step_ca_root.crt.tmp --format pem --bundle \
      | awk 'BEGIN{b=0} /-----BEGIN CERTIFICATE-----/{b++} b==2{print} /-----END CERTIFICATE-----/{if(b==2) exit}' \
      > /certs/step_ca_intermediate.crt.tmp
    openssl x509 -in /certs/step_ca_intermediate.crt.tmp -noout -text | grep -q "CA:TRUE" || return 1
    mv -f /certs/step_ca_root.crt.tmp /certs/step_ca_root.crt
    mv -f /certs/step_ca_intermediate.crt.tmp /certs/step_ca_intermediate.crt
    chmod 0444 /certs/step_ca_root.crt /certs/step_ca_intermediate.crt
    printf '%s' "$STEP_CA_FINGERPRINT" > "$STEP_CA_FINGERPRINT_FILE"
}

if [ "${STEP_CA_ENABLED}" = "true" ]; then
    CACHED_FP=""
    if [ -f "$STEP_CA_FINGERPRINT_FILE" ]; then
        CACHED_FP="$(cat "$STEP_CA_FINGERPRINT_FILE")"
    fi
    if [ "$CACHED_FP" != "$STEP_CA_FINGERPRINT" ]; then
        log "Bootstrapping Step-CA from ${STEP_CA_ENDPOINT} ..."
        if step_ca_bootstrap; then
            log "Step-CA bootstrap complete."
        else
            ## Step-CA may be served by this very Traefik (the usual single
            ## server setup), so it can't answer until Traefik is up. Don't
            ## fail startup: retry in the background, then restart (below):
            log "Step-CA is not reachable yet at ${STEP_CA_ENDPOINT}; starting Traefik without it and retrying in the background."
            log "(mTLS routes won't accept clients until the bootstrap succeeds.)"
            STEP_CA_PENDING=true
        fi
    else
        log "Step-CA already bootstrapped (fingerprint unchanged)."
        ## The system trust store lives in the container, so a recreated
        ## container needs the (saved) root installed again:
        if [ -f /certs/step_ca_root.crt ]; then
            step certificate install /certs/step_ca_root.crt >/dev/null 2>&1 || true
        fi
    fi
fi

# --- Step-CA zero-certs mode: replace system certs with just the Step-CA root ---
: "${STEP_CA_ZERO_CERTS:=false}"
if [ "${STEP_CA_ZERO_CERTS}" = "true" ]; then
    log "Zero-certs mode: replacing system CA bundle with Step-CA root only."
    rm -f /etc/ssl/certs/*
    ln -s /certs/step_ca_root.crt /etc/ssl/certs/ca-certificates.crt
    chmod uog-w /etc/ssl/certs
fi

# --- Background watcher: exits container if restart flag exists and is owned by root ---
watch_restart_flag() {
    rm -f ${RESTART_FLAG}
    while :; do
        if [ -e "$RESTART_FLAG" ]; then
            FILE_UID="$(ls -ln -- "$RESTART_FLAG" 2>/dev/null | awk '{print $3}')"
            if [ -n "$FILE_UID" ] && [ "$FILE_UID" = "0" ]; then
                log "Restart flag found. Stopping Traefik in ${RESTART_DELAY} seconds ..."
                sleep "${RESTART_DELAY}"
                # exit the whole container
                kill -TERM 1
                exit 70
            fi
        fi
        sleep 5    # check every 5 seconds; adjust as needed
    done
}

# --- Wait for main config file ---
log "Waiting for config to be created ..."
FOUND=0
for try in 1 2 3 4 5; do
    if [ -f "$CONFIG" ]; then
        FOUND=1
        break
    fi
    sleep 2
done
if [ "$FOUND" -ne 1 ]; then
    log "Config not found: $CONFIG"
    exit 1
fi
log "Found config: $CONFIG"

# --- Make 'traefik ...' default if first arg is an option ---
if [ "${1#-}" != "$1" ]; then
    set -- traefik "$@"
fi

# --- If first arg is a valid Traefik subcommand, run through traefik ---
if traefik "$1" --help >/dev/null 2>&1; then
    set -- traefik "$@"
else
    log "= '$1' is not a Traefik command: assuming shell execution."
fi

# --- Strip TRAEFIK_LEGO_ prefix so LEGO sees native var names ---
for _var in $(env | grep '^TRAEFIK_LEGO_' | cut -d= -f1); do
    _bare="${_var#TRAEFIK_LEGO_}"
    eval "export ${_bare}=\"\${${_var}}\""
done

# --- Launch background watcher and Traefik as the traefik user ---
watch_restart_flag &

## A pending Step-CA bootstrap retries until Step-CA answers (e.g. through
## this Traefik), then raises the restart flag: the restarted container
## finds the fingerprint cached and starts with the CA loaded:
if [ "${STEP_CA_PENDING}" = "true" ]; then
    (
        while sleep 10; do
            if step_ca_bootstrap >/dev/null 2>&1; then
                log "Step-CA bootstrap complete; restarting Traefik to load it."
                touch "$RESTART_FLAG"
                exit 0
            fi
        done
    ) &
fi

sleep 2
exec su-exec "$TRAEFIK_USER" "$@"
