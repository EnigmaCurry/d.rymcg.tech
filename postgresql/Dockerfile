ARG POSTGRES_VERSION
FROM postgres:${POSTGRES_VERSION}
COPY init-user.sh /docker-entrypoint-initdb.d/init-user.sh
