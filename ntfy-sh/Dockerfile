ARG NTFY_IMAGE
FROM ${NTFY_IMAGE}
ARG UID
ARG GID
RUN addgroup -g ${GID} ntfy && \
    adduser -D -u ${UID} -G ntfy ntfy && \
    mkdir -p /etc/ntfy && \
    mkdir -p /var/cache/ntfy && \
    chown ${UID}:${GID} /var/cache/ntfy && \
    chown ${UID}:${GID} /etc/ntfy
VOLUME /var/cache/ntfy /etc/ntfy
USER ${UID}
