ARG TRAEFIK_IMAGE

## Install plugins from source repositories:
FROM alpine:3 as plugins
ARG BLOCKPATH_MODULE
ARG BLOCKPATH_GIT_BRANCH
ARG REFERER_MODULE
ARG REFERER_GIT_BRANCH
ARG MAXMIND_GEOIP_MODULE
ARG MAXMIND_GIT_BRANCH
RUN apk add --update git && \
    git clone https://${BLOCKPATH_MODULE}.git /plugins-local/src/github.com/traefik/plugin-blockpath \
      --depth 1 --single-branch --branch ${BLOCKPATH_GIT_BRANCH}
RUN git clone https://${MAXMIND_GEOIP_MODULE}.git \
    /plugins-local/src/github.com/forestvpn/traefikgeoip2 \
    --depth 1 --single-branch --branch ${MAXMIND_GIT_BRANCH}
RUN git clone https://${REFERER_MODULE}.git /plugins-local/src/github.com/moonlightwatch/referer \
      --depth 1 --single-branch --branch ${REFERER_GIT_BRANCH}

FROM ${TRAEFIK_IMAGE}
ARG TRAEFIK_UID TRAEFIK_GID TRAEFIK_DOCKER_GID
COPY --from=plugins /plugins-local /plugins-local
COPY entrypoint.sh  /entrypoint_ensure_config.sh
RUN apk --no-cache add curl jq libcap && \
    chmod a+x /entrypoint_ensure_config.sh && \
    addgroup -g ${TRAEFIK_GID} traefik && \
    getent group ${TRAEFIK_DOCKER_GID} || addgroup -g ${TRAEFIK_DOCKER_GID} docker && \
    adduser traefik -D -u ${TRAEFIK_UID} -G traefik && \
    addgroup traefik $(getent group ${TRAEFIK_DOCKER_GID} | cut -d: -f1) && \
    mkdir /data && \
    chown traefik:traefik /data && \
    setcap cap_net_bind_service=+ep /usr/local/bin/traefik
USER traefik
ENTRYPOINT ["/entrypoint_ensure_config.sh"]
VOLUME /data
