#!/bin/bash --noprofile

sleep 2
if [[ $# -gt 0 ]]; then
    echo "## Running the command specified by the docker command line .."
    (set -ex; home-manager switch)
    (set -x; $@)
else
    echo "## Running 'getty' loop .."
    restarted=0
    while true; do
        test "${restarted}" == 1 && echo "## Restarting shell session ..."
        (set -ex; home-manager switch)
        (set -x; bash)
        restarted=1
    done
fi
