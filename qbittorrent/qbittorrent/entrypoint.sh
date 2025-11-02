#!/usr/bin/env bash

# qbittorrent-wrapper – starts qBittorrent and watches
# ${CONFIG_DIR}/qBittorrent/categories.json for changes.

set -euo pipefail

# Configurable locations
CONFIG_DIR="/config"
CATS_FILE="${CONFIG_DIR}/qBittorrent/categories.json"
HASH_FILE="${CONFIG_DIR}/.config_hash"
export QBT_CONFIG=/config/qBittorrent

# Helper: compute MD5
hash_file() {
    md5sum "$1" | cut -d' ' -f1;
}

# Record the current hash on first start (so we only react on real
# changes, not on the initial file being present)
init_hash() {
    if [[ -f "$HASH_FILE" ]]; then
        STORED_HASH=$(cat "$HASH_FILE")
    else
        STORED_HASH=""
    fi
}

# Start qBittorrent in the background and remember its PID.
# NOTE: The official image uses the `qbittorrent-nox` binary. We set
# the location of the config directory in `QBT_CONFIG`, above.
start_qbittorrent() {
    echo "[wrapper] Starting qBittorrent..."
    qbittorrent-nox &
    QB_PID=$!
    echo "[wrapper] qBittorrent PID=${QB_PID}"
}

# Graceful restart
restart_qbittorrent() {
    echo "[wrapper] Restarting qBittorrent (PID ${QB_PID})..."
    kill -TERM "${QB_PID}" 2>/dev/null || true
    wait "${QB_PID}" || true   # wait for clean exit (ignore non‑zero)
    start_qbittorrent
}

# Background watcher restarts qBittorrent on inotify events.
watcher() {
    echo "[watcher] Watching ${CATS_FILE}"
    while true; do
        # Wait for any write/rename/delete that indicates the file changed.
        # `-e close_write,moved_to,delete_self,delete` covers most editors.
        inotifywait -e close_write -e moved_to -e delete_self -e delete "${CATS_FILE}" >/dev/null 2>&1 || true

        # If the file disappeared, treat it as a change.
        if [[ -f "${CATS_FILE}" ]]; then
            CURRENT_HASH=$(hash_file "${CATS_FILE}")
        else
            CURRENT_HASH="__MISSING__"
        fi

        if [[ "${CURRENT_HASH}" != "${STORED_HASH}" ]]; then
            echo "[watcher] Detected change in categories.json"
            echo "${CURRENT_HASH}" > "${HASH_FILE}"
            STORED_HASH="${CURRENT_HASH}"
            restart_qbittorrent
        fi
    done
}

main() {
    init_hash
    start_qbittorrent

    # Run the watcher in the background.
    watcher &

    # Wait for the main process (qbittorrent) to exit.
    # Docker sends SIGTERM/INT to this PID 1 script; we let it
    # propagate to the child via the `wait` builtin.
    wait "${QB_PID}"
    EXIT_CODE=$?
    echo "[wrapper] qBittorrent exited with code ${EXIT_CODE}"
    exit ${EXIT_CODE}
}

main "$@"
