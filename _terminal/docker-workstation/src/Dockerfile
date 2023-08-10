FROM debian:bookworm-slim as openssh-base
RUN set -eux; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq update; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install bash curl openssh-server ssh-import-id; \
    echo "dash dash/sh boolean false" | debconf-set-selections; \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash; \
    mkdir -p /etc/ssh/keys; \
    rm -f /etc/ssh/keys/*; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -m 0755 -p /run/sshd;
ADD sshd_config /etc/ssh/sshd_config
ADD --chmod=0700 sshd_entrypoint.sh /usr/local/bin/sshd_entrypoint.sh
WORKDIR /root
ENTRYPOINT /usr/local/bin/sshd_entrypoint.sh

FROM openssh-base as d.rymcg.tech-base
ADD d.rymcg.tech_motd.txt /etc/motd
RUN set -eux; \
    mkdir -p /usr/local/src/d.rymcg.tech-workstation; \
    echo "In order to minimize the base container image size, only some of the dependencies have been installed by default. This file is placed here as a token to indicate that the extra dependencies of d.rymcg.tech have not been installed yet. The installer will delete this file once that has been done." > /usr/local/src/d.rymcg.tech-workstation/not_installed_yet.txt;
ADD --chmod=0700 install_deps.sh install_d.rymcg.tech.sh /usr/local/src/d.rymcg.tech-workstation
