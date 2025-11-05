ARG QBITTORRENT_IMAGE
FROM ${QBITTORRENT_IMAGE:-linuxserver/qbittorrent:latest}
<<<<<<< HEAD
RUN apk add --no-cache inotify-tools iproute2 iptables libcap

COPY --chmod=0555 entrypoint.sh /usr/local/bin/qbittorrent-wrapper
COPY --chmod=0555 app-router-bootstrap.sh /usr/local/bin/app-router-bootstrap.sh

ENTRYPOINT ["/usr/local/bin/app-router-bootstrap.sh"]
CMD ["/usr/local/bin/qbittorrent-wrapper"]
||||||| 4aaa952
RUN apk add --no-cache inotify-tools
COPY entrypoint.sh /usr/local/bin/qbittorrent-wrapper
RUN chmod +x /usr/local/bin/qbittorrent-wrapper
ENTRYPOINT ["/usr/local/bin/qbittorrent-wrapper"]
=======
RUN apk add --no-cache inotify-tools iproute2 iptables libcap

COPY --chmod=0555 entrypoint.sh /usr/local/bin/qbittorrent-wrapper
COPY --chmod=0555 app-router-bootstrap.sh /usr/local/bin/app-router-bootstrap.sh

ENV ENTRYPOINT=/init
ENTRYPOINT ["/usr/local/bin/app-router-bootstrap.sh"]
CMD ["/usr/local/bin/qbittorrent-wrapper"]
>>>>>>> master
