FROM postgres:13.3
ADD https://raw.githubusercontent.com/ortuman/jackal/master/sql/postgres.up.psql /docker-entrypoint-initdb.d/01-schema.sql
RUN chmod a+r /docker-entrypoint-initdb.d/01-schema.sql
