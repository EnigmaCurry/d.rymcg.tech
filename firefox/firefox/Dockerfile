ARG IMAGE
FROM ${IMAGE}

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    iproute2 \
    iptables \
    iputils-ping \
    gosu \
    ca-certificates \
    libcap2-bin  && \
    rm -rf /var/lib/apt/lists/*

COPY app-router-bootstrap.sh /usr/local/bin/app-router-bootstrap.sh
RUN chmod 0555 /usr/local/bin/app-router-bootstrap.sh

ARG PUID=1000
ARG PGID=1000

ENTRYPOINT ["/usr/local/bin/app-router-bootstrap.sh"]
