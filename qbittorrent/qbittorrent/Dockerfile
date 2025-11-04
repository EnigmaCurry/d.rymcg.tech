ARG QBITTORRENT_IMAGE
FROM ${QBITTORRENT_IMAGE:-linuxserver/qbittorrent:latest}
RUN apk add --no-cache inotify-tools iproute2 iptables libcap

COPY --chmod=0555 entrypoint.sh /usr/local/bin/qbittorrent-wrapper
COPY --chmod=0555 app-router-bootstrap.sh /usr/local/bin/app-router-bootstrap.sh

ENTRYPOINT ["/usr/local/bin/app-router-bootstrap.sh"]
CMD ["/usr/local/bin/qbittorrent-wrapper"]
