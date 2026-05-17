ARG BITMAGNET_IMAGE
FROM ${BITMAGNET_IMAGE:-ghcr.io/bitmagnet-io/bitmagnet:latest}

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk add --no-cache \
    iproute2 \
    iptables \
    nftables \
    iputils-ping \
    ca-certificates \
    libcap \
    gosu \
    bash && \
    rm -rf /var/cache/apk/*

COPY app-router-bootstrap.sh /usr/local/bin/app-router-bootstrap.sh
RUN chmod 0555 /usr/local/bin/app-router-bootstrap.sh

ARG PUID=1000
ARG PGID=1000

ENTRYPOINT ["/usr/local/bin/app-router-bootstrap.sh"]
CMD ["/usr/local/bin/bitmagnet"]
