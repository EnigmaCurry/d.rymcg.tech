ARG TRAEFIK_IMAGE

## Install plugins from source repositories:
FROM alpine:3 as plugins
ARG BLOCKPATH_MODULE=github.com/traefik/plugin-blockpath
ARG BLOCKPATH_GIT_BRANCH=master
ARG MAXMIND_GEOIP_MODULE=github.com/GiGInnovationLabs/traefikgeoip2
ARG MAXMIND_GIT_BRANCH=main
RUN apk add --update git && \
    git clone https://${BLOCKPATH_MODULE}.git /plugins-local/src/${BLOCKPATH_MODULE} \
      --depth 1 --single-branch --branch ${BLOCKPATH_GIT_BRANCH} && \
    git clone https://${MAXMIND_GEOIP_MODULE}.git \
      /plugins-local/src/${MAXMIND_GEOIP_MODULE} \
      --depth 1 --single-branch --branch ${MAXMIND_GIT_BRANCH}

FROM ${TRAEFIK_IMAGE}
COPY --from=plugins /plugins-local /plugins-local
