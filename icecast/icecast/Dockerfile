FROM debian:bullseye
ARG UID=1000
ARG GID=1000
ARG USERNAME=debian-user
RUN groupadd -g "${GID}" "${USERNAME}" && \
    adduser --uid "${UID}" --gid "${GID}" \
    --gecos "" --disabled-password "${USERNAME}"
RUN mkdir /config && touch /config/icecast.xml && \
    ln -s /config/icecast.xml /etc/icecast.xml && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y icecast2 media-types && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/log/icecast && \
    chown -R "${UID}:${GID}" /var/log/icecast

USER ${USERNAME}
CMD ["/usr/bin/icecast2", "-c", "/config/icecast.xml"]
EXPOSE 8000
