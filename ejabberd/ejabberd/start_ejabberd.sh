#!/bin/bash

wait_for_file() {
    [ ! -f $1 ] && echo "Waiting for $1 to exist ..."
    until [ -f $1 ]; do sleep 1; done
}

wait_for_file /home/ejabberd/conf/${EJABBERD_HOST}/cert.pem
wait_for_file /home/ejabberd/conf/${EJABBERD_HOST}/key.pem

/home/ejabberd/bin/ejabberdctl --config /home/ejabberd/conf/${EJABBERD_HOST}/ejabberd.yml foreground


