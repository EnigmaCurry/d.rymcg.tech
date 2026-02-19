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

FROM ${TRAEFIK_IMAGE} AS traefik
COPY --from=plugins /plugins-local /plugins-local
COPY entrypoint.sh  /entrypoint_ensure_config.sh
RUN apk --no-cache add curl jq bind-tools libcap step-cli openssl su-exec && \
    chmod a+x /entrypoint_ensure_config.sh && \
    mkdir /data && \
    setcap cap_net_bind_service=+ep /usr/local/bin/traefik

ENV STEPPATH=/certs/step
ENTRYPOINT ["/entrypoint_ensure_config.sh"]
VOLUME /data

HEALTHCHECK --interval=10s --timeout=5s --retries=3 CMD \
  sh -c 'curl -fsS --max-time 5 http://127.0.0.1:8080/ping \
         || [ $? -eq 22 ]'
