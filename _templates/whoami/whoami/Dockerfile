FROM alpine:3
ARG UID
ARG GID
ARG USERNAME

RUN addgroup -g ${GID} ${USERNAME} && \
    adduser -D -u ${UID} -G ${USERNAME} -h /home/${USERNAME} ${USERNAME}
COPY --from=traefik/whoami:latest /whoami /usr/local/bin/whoami

EXPOSE 8000
CMD /usr/local/bin/whoami --port 8000 --name "${DOCKER_PROJECT}_${DOCKER_INSTANCE}"
