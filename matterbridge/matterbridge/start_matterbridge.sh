#!/bin/bash

wait_for_file() {
    [ ! -f $1 ] && echo "Waiting for $1 to exist ..."
    until [ -f $1 ]; do sleep 1; done
}

wait_for_file /etc/matterbridge/matterbridge.toml
/go/bin/matterbridge -conf /etc/matterbridge/matterbridge.toml "$@"

