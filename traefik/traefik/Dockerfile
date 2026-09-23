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
RUN git clone https://${HEADER_AUTHORIZATION_MODULE}.git /plugins-local/src/github.com/enigmacurry/traefik-header-authorization \
      --depth 1 --single-branch --branch ${HEADER_AUTHORIZATION_GIT_BRANCH}
RUN git clone https://${CERT_AUTH_MODULE}.git /plugins-local/src/github.com/famedly/traefik-certauthz \
      --depth 1 --single-branch --branch ${CERT_AUTH_GIT_BRANCH}
RUN git clone https://${MTLS_HEADER_MODULE}.git /plugins-local/src/github.com/pnxs/traefik-plugin-mtls-header \
      --depth 1 --single-branch --branch ${MTLS_HEADER_GIT_BRANCH}
## Validate each cloned plugin matches the module name that traefik expects.
## The directory name under /plugins-local/src must equal the module declared
## in go.mod, the .traefik.yml import must start with that module name, and
## the Go package name must match the basePkg (or the derived form).
## A mismatch here would disable ALL plugins at runtime, so fail the build:
RUN for dir in /plugins-local/src/github.com/*/*/; do \
        name=${dir#/plugins-local/src/}; \
        name=${name%/}; \
        mod=$(grep -m1 '^module ' "${dir}go.mod" | awk '{print $2}'); \
        if [ "${mod}" != "${name}" ]; then \
            echo "ERROR: plugin '${name}': go.mod declares module '${mod}', expected '${name}'" >&2; \
            exit 1; \
        fi; \
        imp=$(grep -m1 '^import:' "${dir}.traefik.yml" | awk '{print $2}'); \
        case "${imp}" in \
            "${name}"|${name}/*) : ;; \
            *) echo "ERROR: plugin '${name}': .traefik.yml import '${imp}' must start with module name '${name}'" >&2; exit 1 ;; \
        esac; \
        pkg=$(grep -m1 '^basePkg:' "${dir}.traefik.yml" | awk '{print $2}'); \
        if [ -z "${pkg}" ]; then \
            pkg=$(printf '%s\n' "${imp##*/}" | tr '-' '_'); \
        fi; \
        for f in "${dir}"*.go; do \
            [ -e "${f}" ] || continue; \
            case "${f}" in \
                *_test.go) : ;; \
                *) actual=$(grep -m1 '^package ' "${f}" | awk '{print $2}'); \
                   if [ "${actual}" != "${pkg}" ]; then \
                       echo "ERROR: plugin '${name}': ${f##*/} declares package '${actual}', expected '${pkg}'" >&2; \
                       exit 1; \
                   fi ;; \
            esac; \
        done; \
        echo "OK: plugin '${name}'"; \
    done

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
