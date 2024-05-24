#!/bin/bash

## SLEEP is the minimum time (seconds) between two renders
SLEEP=${SLEEP:-30}
## WAIT is the amount of time (seconds) between when a render is triggered and when it is started
WAIT=${WAIT:-5}

alias grep='grep --line-buffered'

TMP_DIR=$(mktemp -d)
cleanup() { set -ex; rm -rf ${TMP_DIR}; }
trap cleanup SIGINT SIGTERM SIGQUIT SIGABRT ERR EXIT
echo "## TMP_DIR=${TMP_DIR}"

monitor() {
    CHANGES_PENDING=0
    LAST_RENDER_TIME=0
    while [[ true ]]; do
        if [[ CHANGES_PENDING -gt 0 ]]; then
            # Render accumulated events
            CHANGES_PENDING=0
            LAST_RENDER_TIME=$(date +%s)
            render
        fi
        echo "# $(date) :: Waiting for changes ..."
        inotifywait --monitor --recursive --event close_write --timeout ${SLEEP} /tiddlywiki \
                    2>${TMP_DIR}/stderr.txt | \
            grep -v '$__StoryList.tid' | \
            while read path events file; do
                echo "$events $file"
                # TIME_DIFF=$(($(date +%s) - ${LAST_RENDER_TIME}));
                # if [[ TIME_DIFF -lt SLEEP ]]; then
                #     CHANGES_PENDING=1
                #     echo "## Queing render for: $file"
                #     continue
                # else
                #     # Immediately render
                #     CHANGES_PENDING=0
                #     LAST_RENDER_TIME=$(date +%s)
                #     echo "## Immediate render for: $file"
                #     render
                # fi
            done
        if [ $? -eq 1 ]; then
            echo "## Error:"
            cat ${TMP_DIR}/stderr.txt && truncate --size 0 ${TMP_DIR}/stderr.txt
        fi
        sleep 1
    done
}

render() {
    echo "# $(date) :: OK rendering now ..."
    #(set -x; sleep ${WAIT})
}


monitor
