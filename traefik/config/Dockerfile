FROM debian:stable-slim AS ytt
ARG TRAEFIK_CONFIG_YTT_VERSION
RUN apt update && apt install -y wget && wget "https://github.com/vmware-tanzu/carvel-ytt/releases/download/${TRAEFIK_CONFIG_YTT_VERSION}/ytt-linux-$(dpkg --print-architecture)" -O ytt && install ytt /usr/local/bin/ytt

FROM ytt
WORKDIR /template
COPY setup.sh traefik.yml config-template ./
COPY context-template ./context-template
ARG TRAEFIK_UID TRAEFIK_GID
RUN chmod a+x setup.sh && \
    addgroup --gid ${TRAEFIK_GID} traefik && \
    adduser traefik --disabled-password --uid ${TRAEFIK_UID} --ingroup traefik && \
    mkdir /data && \
    chown traefik:traefik /data
USER traefik
VOLUME /config
CMD ["./setup.sh"]
