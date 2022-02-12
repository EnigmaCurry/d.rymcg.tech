#!/bin/bash

wait_for_file() {
    [ ! -f $1 ] && echo "Waiting for $1 to exist ..."
    until [ -f $1 ]; do sleep 1; done
}

wait_for_file /cert/key.pem
wait_for_file /cert/cert.pem
wait_for_file /cert/fullchain.pem

/home/ejabberd/bin/ejabberdctl --config /home/ejabberd/conf/${EJABBERD_HOST}/ejabberd.yml foreground


