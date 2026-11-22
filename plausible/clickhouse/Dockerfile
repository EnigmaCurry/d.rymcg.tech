ARG PLAUSIBLE_CLICKHOUSE_IMAGE
FROM ${PLAUSIBLE_CLICKHOUSE_IMAGE}
## Config from https://github.com/plausible/community-edition/tree/v3.2.1/clickhouse
## Quiet logging, IPv4-only listening, and low resource usage:
COPY logs.xml ipv4-only.xml low-resources.xml /etc/clickhouse-server/config.d/
COPY default-profile-low-resources-overrides.xml /etc/clickhouse-server/users.d/
