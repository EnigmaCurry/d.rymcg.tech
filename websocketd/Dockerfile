## Build container (websocketd's Makefile now expects Go to be installed)::
FROM golang:1.24-trixie
## Upstream has no tag newer than v0.4.1 (2021), so pin a commit on main:
ARG WEBSOCKETD_VERSION
WORKDIR /usr/local/src/websocketd
RUN test -n "${WEBSOCKETD_VERSION}" || { echo "WEBSOCKETD_VERSION is not set (see .env-dist)" >&2; exit 1; } && \
    git init -q . && \
    git remote add origin https://github.com/joewalnes/websocketd.git && \
    git fetch -q --depth 1 origin "${WEBSOCKETD_VERSION}" && \
    git checkout -q FETCH_HEAD && \
    CGO_ENABLED=0 go build -o websocketd .


## App container (demo count.sh app)::
FROM debian:13
COPY --from=0 /usr/local/src/websocketd/websocketd /usr/local/bin/
COPY --from=0 /usr/local/src/websocketd/examples/bash/count.sh /usr/local/bin/app
COPY entrypoint.sh /usr/local/bin
RUN chmod a+x /usr/local/bin/app /usr/local/bin/entrypoint.sh

EXPOSE 8080
ENTRYPOINT /usr/local/bin/entrypoint.sh
