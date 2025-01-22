ARG MOSQUITTO_IMAGE
FROM ${MOSQUITTO_IMAGE}
COPY --chmod=755 mosquitto-entrypoint.sh /mosquitto/mosquitto-entrypoint.sh
ENTRYPOINT ["/mosquitto/mosquitto-entrypoint.sh"]
