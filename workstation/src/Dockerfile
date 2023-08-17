FROM debian:bookworm-slim as openssh-base
RUN set -eux; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq update; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install bash curl openssh-server ssh-import-id sudo ca-certificates gnupg; \
    echo "dash dash/sh boolean false" | debconf-set-selections; \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash; \
    rm -rf /etc/ssh; \
    mkdir -m 0755 -p /run/sshd; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    chmod a+r /etc/apt/keyrings/docker.gpg; \
    echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null; \
    rm -rf /var/lib/apt/lists/*;

ADD --chmod=0400 workstation_sudoers /etc/sudoers.d/workstation_sudoers
ADD --chmod=0555 sshd_entrypoint.sh /usr/local/bin/sshd_entrypoint.sh
ENTRYPOINT ["/bin/bash", "/usr/local/bin/sshd_entrypoint.sh"]

FROM openssh-base as d.rymcg.tech-base
ADD d.rymcg.tech_motd.txt /etc/motd
RUN set -eux; \
    mkdir -p /usr/local/template/d.rymcg.tech-workstation;
ADD bash_profile.sh bashrc.sh install_d.rymcg.tech.sh /usr/local/template/d.rymcg.tech-workstation/
