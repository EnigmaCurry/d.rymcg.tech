FROM clickhouse/clickhouse-server:22.6-alpine
# All this does is quiet down the logging.
COPY ./clickhouse-config.xml /etc/clickhouse-server/config.d/logging.xml
COPY ./clickhouse-user-config.xml /etc/clickhouse-server/users.d/logging.xml