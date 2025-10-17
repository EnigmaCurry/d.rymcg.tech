ARG TRAEFIK_IMAGE

## Install plugins from source repositories:
FROM alpine:3 AS plugins
ARG BLOCKPATH_MODULE
ARG BLOCKPATH_GIT_BRANCH
ARG REFERER_MODULE
ARG REFERER_GIT_BRANCH
ARG MAXMIND_GEOIP_MODULE
ARG MAXMIND_GIT_BRANCH
ARG HEADER_AUTHORIZATION_MODULE
ARG HEADER_AUTHORIZATION_GIT_BRANCH
ARG CERT_AUTH_MODULE
ARG CERT_AUTH_GIT_BRANCH
ARG MTLS_HEADER_MODULE
ARG MTLS_HEADER_GIT_BRANCH
RUN apk add --update git && \
    git clone https://${BLOCKPATH_MODULE}.git /plugins-local/src/github.com/traefik/plugin-blockpath \
      --depth 1 --single-branch --branch ${BLOCKPATH_GIT_BRANCH}
RUN git clone https://${MAXMIND_GEOIP_MODULE}.git \
    /plugins-local/src/github.com/forestvpn/traefikgeoip2 \
    --depth 1 --single-branch --branch ${MAXMIND_GIT_BRANCH}
RUN git clone https://${REFERER_MODULE}.git /plugins-local/src/github.com/moonlightwatch/referer \
      --depth 1 --single-branch --branch ${REFERER_GIT_BRANCH}
RUN git clone https://${HEADER_AUTHORIZATION_MODULE}.git /plugins-local/src/github.com/poloyacero/headauth \
      --depth 1 --single-branch --branch ${HEADER_AUTHORIZATION_GIT_BRANCH}
RUN git clone https://${CERT_AUTH_MODULE}.git /plugins-local/src/github.com/famedly/traefik-certauthz \
      --depth 1 --single-branch --branch ${CERT_AUTH_GIT_BRANCH}
RUN git clone https://${MTLS_HEADER_MODULE}.git /plugins-local/src/github.com/pnxs/traefik-plugin-mtls-header \
      --depth 1 --single-branch --branch ${MTLS_HEADER_GIT_BRANCH}

FROM ${TRAEFIK_IMAGE} as traefik
ARG TRAEFIK_UID TRAEFIK_GID TRAEFIK_DOCKER_GID
COPY --from=plugins /plugins-local /plugins-local
COPY entrypoint.sh  /entrypoint_ensure_config.sh
RUN apk --no-cache add curl jq bind-tools libcap step-cli && \
    chmod a+x /entrypoint_ensure_config.sh && \
    addgroup -g ${TRAEFIK_GID} traefik && \
    getent group ${TRAEFIK_DOCKER_GID} || addgroup -g ${TRAEFIK_DOCKER_GID} docker && \
    adduser traefik -D -u ${TRAEFIK_UID} -G traefik && \
    addgroup traefik $(getent group ${TRAEFIK_DOCKER_GID} | cut -d: -f1) && \
    mkdir /data && \
    chown traefik:traefik /data && \
    setcap cap_net_bind_service=+ep /usr/local/bin/traefik
ARG STEP_CA_ENABLED STEP_CA_ENDPOINT STEP_CA_FINGERPRINT
RUN test "${STEP_CA_ENABLED}" != "true" && exit || \
    step ca bootstrap --ca-url "${STEP_CA_ENDPOINT}" --install --force --fingerprint "${STEP_CA_FINGERPRINT}" && \
    step ca roots > /step_ca_root.crt && \
    chmod 0444 /step_ca_root.crt
ARG STEP_CA_ZERO_CERTS
RUN test "${STEP_CA_ZERO_CERTS}" != "true" && exit || \
    rm -f /etc/ssl/certs/* && \
    ln -s /step_ca_root.crt /etc/ssl/certs/ca-certificates.crt && \
    chmod uog-w /etc/ssl/certs

# Cache bust the image with the current env file contents.
# This forces Traefik to restart for all config changes.
# Actual env file contents go to /dev/null so they don't end up in the image layer.
ARG ENV_FILE
COPY ${ENV_FILE} /dev/null

USER traefik
ENTRYPOINT ["/entrypoint_ensure_config.sh"]
VOLUME /data

HEALTHCHECK --interval=10s --timeout=5s --retries=3 CMD \
  sh -c 'curl -fsS --max-time 5 http://127.0.0.1:8080/ping \
         || [ $? -eq 22 ]'
