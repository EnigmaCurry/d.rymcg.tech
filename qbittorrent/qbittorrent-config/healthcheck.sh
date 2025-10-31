#!/bin/sh
if [ ! -f /config/.config_hash ]; then
    exit 1
fi
current_hash=$(md5sum /config/qBittorrent/categories.json 2>/dev/null | cut -d" " -f1)
if [ -z "$current_hash" ]; then
    exit 1
fi
stored_hash=$(cat /config/.config_hash)
if [ "$current_hash" != "$stored_hash" ]; then
    echo "$current_hash" > /config/.config_hash
    # Kill the main process (pid 1)
    kill 1
    exit 1
fi
exit 0
