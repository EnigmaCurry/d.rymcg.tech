#!/bin/sh

if [ ! -f /etc/systemd/system/faasd.service ]; then
    exec /sbin/init --log-level=info &
    echo "Waiting to install faasd in 5..4..3..2..1.."
    sleep 5
    ~/git/vendor/openfaas/faasd/hack/install.sh
    fg
else
    exec /sbin/init --log-level=info
fi
