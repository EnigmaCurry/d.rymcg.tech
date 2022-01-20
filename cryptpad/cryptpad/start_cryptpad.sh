#!/bin/bash

wait_for_file() {
    [ ! -f $1 ] && echo "Waiting for $1 to exist ..."
    until [ -f $1 ]; do sleep 1; done
}

wait_for_file /cryptpad/config/config.js
/usr/bin/supervisord -n -c /etc/supervisord.conf
