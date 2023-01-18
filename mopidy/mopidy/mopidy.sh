#!/bin/bash

# Copy config if it does not already exist
if [ ! -f /home/mopidy/.config/mopidy/mopidy.conf ]; then
    cp /mopidy_default.conf /home/mopidy/.config/mopidy/mopidy.conf
fi

if [ ${APT_PACKAGES:+x} ]; then
    echo "-- INSTALLING APT PACKAGES $APT_PACKAGES --"
    sudo apt-get update
    sudo apt-get install -y $APT_PACKAGES
fi
if  [ ${PIP_PACKAGES:+x} ]; then
    echo "-- INSTALLING PIP PACKAGES $PIP_PACKAGES --"
    pip3 install $PIP_PACKAGES
fi
if [ ${UPDATE:+x} ]; then
    echo "-- UPDATING ALL PACKAGES --"
    sudo apt-get update
    sudo apt-get upgrade -y
    pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U # Upgrade all pip packages
fi

exec mopidy --config /home/mopidy/.config/mopidy/mopidy.conf "$@"
