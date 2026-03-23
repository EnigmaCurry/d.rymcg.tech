ARG NATS_IMAGE
FROM ${NATS_IMAGE}
COPY --chmod=755 nats-entrypoint.sh /nats-entrypoint.sh
ENTRYPOINT ["/nats-entrypoint.sh"]
