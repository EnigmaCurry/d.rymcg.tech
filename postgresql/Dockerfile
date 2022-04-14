ARG POSTGRES_VERSION=14

FROM postgres:${POSTGRES_VERSION} as build
ARG PGRATIONAL_VERSION=v0.0.2
WORKDIR /src
RUN apt-get update && \

    ## Install pg_rational
    apt-get install -y build-essential git postgresql-server-dev-all && \
    git clone https://github.com/begriffs/pg_rational.git && \
    cd pg_rational && \
    git checkout ${PGRATIONAL_VERSION} && \
    make && \
    make install && \

    ## Cleanup
    rm -rf /src && \
    apt-get remove build-essential git postgresql-server-dev-all && \
    apt-get --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

