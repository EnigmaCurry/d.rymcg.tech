#!/bin/bash

    # DEBIAN_FRONTEND=noninteractive apt-get -qq install bash openssl apache2-utils xdg-utils jq sshfs ca-certificates curl gnupg bsdextrautils openssh-server ssh-import-id; \
    # install -m 0755 -d /etc/apt/keyrings; \
    # curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    # chmod a+r /etc/apt/keyrings/docker.gpg; \
    # echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null; \
    # DEBIAN_FRONTEND=noninteractive apt-get -qq update; \
    # DEBIAN_FRONTEND=noninteractive apt-get -qq install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
