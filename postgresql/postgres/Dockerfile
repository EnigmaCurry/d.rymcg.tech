ARG POSTGRES_VERSION

FROM golang:1 as tinycron
RUN git clone https://github.com/EnigmaCurry/tinycron.git /usr/src/tinycron
WORKDIR /usr/src/tinycron
RUN make build

FROM postgres:${POSTGRES_VERSION} as build
ARG PGRATIONAL_VERSION
RUN apt-get update && \
    mkdir -p /src && \
    cd /src && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential git postgresql-server-dev-all pgloader && \
    git clone https://github.com/begriffs/pg_rational.git && \
    cd pg_rational && \
    git checkout ${PGRATIONAL_VERSION} && \
    make && \
    make install

FROM postgres:${POSTGRES_VERSION}
ARG POSTGRES_VERSION
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl pgloader cron procps daemontools && \

    ## Install pgBackRest
    echo "deb https://apt.postgresql.org/pub/repos/apt $(cat /etc/os-release | grep "VERSION_CODENAME" | cut -d '=' -f 2)-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    gpg --dearmor -o /usr/share/keyrings/postgres.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgres.gpg] https://apt.postgresql.org/pub/repos/apt $(cat /etc/os-release | grep "VERSION_CODENAME" | cut -d '=' -f 2)-pgdg main" \
      | tee -a /etc/apt/sources.list.d/postgres.list > /dev/null && \

    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y pgbackrest && \

    rm /etc/pgbackrest.conf && \
    ln -s /etc/postgresql/pgbackrest.conf /etc/pgbackrest.conf  && \

    ## Cleanup
    cd /root && \
#    rm -rf /src && \
    DEBIAN_FRONTEND=noninteractive apt-get -y remove curl && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY init-user.sh /docker-entrypoint-initdb.d/init-user.sh

## Copy from the pgrational build stage into the final image:
## These steps are tested on pg_rational v0.0.2 and may need updating for new POSTGRES_PGRATIONAL_VERSION.
COPY --from=build --chmod=0644 /src/pg_rational/pg_rational.control /src/pg_rational/pg_rational-*.sql /usr/share/postgresql/${POSTGRES_VERSION}/extension/
COPY --from=build --chmod=0755 /src/pg_rational/pg_rational.so /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build --chmod=0644 /src/pg_rational/pg_rational.bc /usr/lib/postgresql/${POSTGRES_VERSION}/lib/bitcode/pg_rational/
COPY --from=build --chmod=0644 /usr/lib/postgresql/${POSTGRES_VERSION}/lib/bitcode/pg_rational.index.bc /usr/lib/postgresql/${POSTGRES_VERSION}/lib/bitcode/pg_rational.index.bc

WORKDIR /root
COPY --from=tinycron /usr/src/tinycron/build/tinycron /usr/local/bin/tinycron
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/healthcheck.sh && \
    mkdir -p /var/lib/postgresql && \
    chown postgres:postgres /var/lib/postgresql
ENTRYPOINT /usr/local/bin/entrypoint.sh
