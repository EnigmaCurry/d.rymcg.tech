FROM debian:bullseye-slim as docker-base
RUN set -eux; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq update; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install bash build-essential openssl apache2-utils xdg-utils jq sshfs wireguard ca-certificates curl gnupg; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    chmod a+r /etc/apt/keyrings/docker.gpg; \
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq update; \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
    echo "dash dash/sh boolean false" | debconf-set-selections; \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash;

FROM docker-base as d-rymcg-tech-workstation
ARG GIT_REPO=https://github.com/EnigmaCurry/d.rymcg.tech.git GIT_BRANCH=master ROOT_DIR=/root/git/vendor/enigmacurry/d.rymcg.tech
RUN git clone ${GIT_REPO} ${ROOT_DIR}; \
    cd ${ROOT_DIR}; \
    git checkout ${GIT_BRANCH}
VOLUME /root
WORKDIR ${ROOT_DIR}
ADD bashrc.sh /root/.bashrc
CMD /bin/sleep infinity
