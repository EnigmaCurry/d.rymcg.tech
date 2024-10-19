#!/bin/sh

if [ ! -f /etc/systemd/system/faasd.service ]; then
    ~/git/vendor/openfaas/faasd/hack/install.sh
fi

exec /sbin/init --log-level=info
