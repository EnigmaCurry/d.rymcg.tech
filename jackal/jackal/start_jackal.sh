#!/bin/bash

wait_for_file() {
    [ ! -f $1 ] && echo "Waiting for $1 to exist ..."
    until [ -f $1 ]; do sleep 1; done
}

wait_for_file /config/config.yaml
wait_for_file /config/cert.pem
wait_for_file /config/key.pem

/jackal/wait-for-it.sh pgsql:5432
/jackal/wait-for-it.sh etcd:2379
/jackal/jackal

