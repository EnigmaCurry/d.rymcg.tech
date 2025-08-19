FROM debian:13-slim AS ytt
ARG TRAEFIK_CONFIG_YTT_VERSION
RUN apt update && apt install -y wget adduser && wget "https://github.com/vmware-tanzu/carvel-ytt/releases/download/${TRAEFIK_CONFIG_YTT_VERSION}/ytt-linux-$(dpkg --print-architecture)" -O ytt && install ytt /usr/local/bin/ytt

FROM ytt
WORKDIR /template
COPY setup.sh traefik.yml config-template ./
COPY context-template ./context-template
ARG TRAEFIK_UID TRAEFIK_GID
RUN chmod a+x setup.sh && \
    addgroup --gid ${TRAEFIK_GID} traefik && \
    adduser \
      --uid ${TRAEFIK_UID} \
      --ingroup traefik \
      --disabled-password \
      --gecos "" \
      --no-create-home \
      --shell /usr/sbin/nologin \
      traefik && \
    mkdir /data && \
    chown traefik:traefik /data
USER traefik
VOLUME /config
CMD ["./setup.sh"]
