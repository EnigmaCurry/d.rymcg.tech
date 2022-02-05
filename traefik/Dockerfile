ARG TRAEFIK_IMAGE

FROM alpine:3
ARG BLOCKPATH_MODULE=github.com/traefik/plugin-blockpath
ARG BLOCKPATH_GIT_BRANCH=master
RUN apk add --update git && \
    git clone https://${BLOCKPATH_MODULE}.git /plugins-local/src/${BLOCKPATH_MODULE} \
      --depth 1 --single-branch --branch ${BLOCKPATH_GIT_BRANCH}

FROM ${TRAEFIK_IMAGE}
COPY --from=0 /plugins-local /plugins-local
