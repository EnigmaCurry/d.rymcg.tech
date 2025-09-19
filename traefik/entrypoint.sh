#!/bin/sh
set -e

CONFIG=/data/config/traefik.yml
RESTART_FLAG=/data/restart_me
RESTART_DELAY=10

log() { printf '%s\n' "$*"; }

# --- Background watcher: exits container if restart flag exists and is owned by Traefik user ---
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

# --- Launch background watcher and Traefik ---
watch_restart_flag &

sleep 2
exec "$@"
