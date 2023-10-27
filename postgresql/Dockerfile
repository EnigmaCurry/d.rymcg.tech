ARG POSTGRES_VERSION=14

FROM postgres:${POSTGRES_VERSION}
ARG PGRATIONAL_VERSION=v0.0.2
WORKDIR /src
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl && \

    ## Install pgBackRest
    echo "deb https://apt.postgresql.org/pub/repos/apt $(cat /etc/os-release | grep "VERSION_CODENAME" | cut -d '=' -f 2)-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    gpg --dearmor -o /usr/share/keyrings/postgres.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgres.gpg] https://apt.postgresql.org/pub/repos/apt $(cat /etc/os-release | grep "VERSION_CODENAME" | cut -d '=' -f 2)-pgdg main" \
      | tee -a /etc/apt/sources.list.d/postgres.list > /dev/null && \

    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y pgbackrest && \

    ## Install pg_rational
    DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential git postgresql-server-dev-all pgloader && \
    git clone https://github.com/begriffs/pg_rational.git && \
    cd pg_rational && \
    git checkout ${PGRATIONAL_VERSION} && \
    make && \
    make install && \
    cd .. \

    ## Cleanup
    rm -rf /src && \
    apt-get remove -y build-essential git postgresql-server-dev-all && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY init-user.sh /docker-entrypoint-initdb.d/init-user.sh
