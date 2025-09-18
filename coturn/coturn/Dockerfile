ARG COTURN_IMAGE
FROM ${COTURN_IMAGE}

USER root
RUN apt-get update && \
    apt-get install -y gosu python3 && \
    rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY get-credentials.sh /usr/local/bin/get-credentials.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
