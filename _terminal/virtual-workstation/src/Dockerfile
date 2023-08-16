FROM debian:bookworm-slim as openssh-base
ARG VIRTUAL_WORKSTATION_UID VIRTUAL_WORKSTATION_GID VIRTUAL_WORKSTATION_USER
RUN set -eux; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq update; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install bash curl openssh-server ssh-import-id; \
    echo "dash dash/sh boolean false" | debconf-set-selections; \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash; \
    rm -rf /etc/ssh; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -m 0755 -p /run/sshd; \
    groupadd -g ${VIRTUAL_WORKSTATION_GID} ${VIRTUAL_WORKSTATION_USER}; \
    useradd -d /home -m --uid=${VIRTUAL_WORKSTATION_UID} --gid=${VIRTUAL_WORKSTATION_GID} ${VIRTUAL_WORKSTATION_USER}; \
    chown -R ${VIRTUAL_WORKSTATION_USER}:${VIRTUAL_WORKSTATION_USER} /home /run/sshd;

USER ${VIRTUAL_WORKSTATION_USER}
WORKDIR /home
RUN mkdir -p ssh/keys
ADD --chown=root:root --chmod=0444 sshd_config /etc/ssh/sshd_config
ADD --chown=root:root --chmod=0555 sshd_entrypoint.sh /usr/local/bin/sshd_entrypoint.sh
ENTRYPOINT /usr/local/bin/sshd_entrypoint.sh

FROM openssh-base as d.rymcg.tech-base
ADD d.rymcg.tech_motd.txt /etc/motd
RUN set -eux; \
    mkdir -p ./src/d.rymcg.tech-workstation; \
    echo "In order to minimize the base container image size, only some of the dependencies have been installed by default. This file is placed here as a token to indicate that the extra dependencies of d.rymcg.tech have not been installed yet. The installer will delete this file once that has been done." > ./src/d.rymcg.tech-workstation/not_installed_yet.txt;
ADD --chmod=0700 install_deps.sh install_d.rymcg.tech.sh ./src/d.rymcg.tech-workstation
VOLUME /home
