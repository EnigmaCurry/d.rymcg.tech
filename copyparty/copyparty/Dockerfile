ARG COPYPARTY_IMAGE
FROM ${COPYPARTY_IMAGE}
RUN apk add --no-cache -U bash

ARG COPYPARTY_UID
ARG COPYPARTY_GID

RUN addgroup -S -g "${COPYPARTY_GID}" copyparty && \
    adduser -S -u "${COPYPARTY_UID}" -G copyparty -h /home/copyparty -D copyparty && \
    mkdir -p /home/copyparty /data && \
    chown -R copyparty:copyparty /data /home/copyparty

USER copyparty
WORKDIR /data
ENTRYPOINT ["python3", "-m", "copyparty", "-c", "/etc/copyparty/copyparty.conf"]
