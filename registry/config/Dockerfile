FROM alpine:3.20

COPY entrypoint.sh /usr/local/bin/config-entrypoint.sh
RUN chmod 0755 /usr/local/bin/config-entrypoint.sh

USER 0:0
ENTRYPOINT ["/usr/local/bin/config-entrypoint.sh"]
