## Adapted from https://github.com/anaxios/soju-docker/blob/master/Dockerfile - Thank you anaxios.

FROM debian:trixie-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    golang \
    build-essential \
    libsqlite3-dev \
    scdoc \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

FROM base AS builder

ARG GIT_REPO
ARG GIT_REF

RUN git clone --no-checkout "${GIT_REPO}" /tmp/soju \
 && cd /tmp/soju \
 && git fetch --depth 1 origin "${GIT_REF}" \
 && git checkout --detach FETCH_HEAD \
 && make \
 && make PREFIX=/tmp/soju-bin install

FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/soju-bin/bin/soju /usr/local/bin/soju
COPY --from=builder /tmp/soju-bin/bin/sojudb /usr/local/bin/sojudb

RUN mkdir -p /run/soju /var/lib/soju

EXPOSE 6667

CMD ["soju"]
