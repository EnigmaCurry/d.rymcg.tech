#!/bin/bash

set -e

SLEEP=30
TIMEOUT=600
LAST_RENDER_TIME=0

while [[ true ]]; do
    TIME_DIFF=$(($(date +%s) - ${LAST_RENDER_TIME}));
    if [[ "$TIME_DIFF" -lt SLEEP ]]; then
        (set -x; sleep $((${SLEEP} - ${TIME_DIFF})))
    fi
    echo "# Waiting for changes ..."
    inotifywait --recursive --timeout ${TIMEOUT} -e CLOSE_WRITE /tiddlywiki 2>/dev/null
    echo "# OK rendering now ..."
    sleep 5
    
    LAST_RENDER_TIME=$(date +%s)
done


