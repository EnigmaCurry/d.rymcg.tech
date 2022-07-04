ARG POSTGRES_VERSION=14

FROM postgres:${POSTGRES_VERSION}
ARG PGRATIONAL_VERSION=v0.0.2
WORKDIR /src
RUN apt-get update && \

    ## Install pg_rational
    DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential git postgresql-server-dev-all pgloader && \
    git clone https://github.com/begriffs/pg_rational.git && \
    cd pg_rational && \
    git checkout ${PGRATIONAL_VERSION} && \
    make && \
    make install && \

    ## Cleanup
    rm -rf /src && \
    apt-get remove -y build-essential git postgresql-server-dev-all && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY init-user.sh /docker-entrypoint-initdb.d/init-user.sh
