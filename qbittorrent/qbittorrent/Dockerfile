FROM ${QBITTORRENT_IMAGE:-linuxserver/qbittorrent:latest}
RUN apk add --no-cache inotify-tools
COPY entrypoint.sh /usr/local/bin/qbittorrent-wrapper
RUN chmod +x /usr/local/bin/qbittorrent-wrapper
ENTRYPOINT ["/usr/local/bin/qbittorrent-wrapper"]
