ARG HOMEPAGE_IMAGE
FROM ${HOMEPAGE_IMAGE}
RUN apk add --no-cache bash openssh git envsubst grep rsync
WORKDIR /app
## Upstream images since v2.x no longer ship /app/config, so Docker would
## create the config volume's mountpoint owned by /app's owner (1000). The
## reloader runs as root with all capabilities dropped and couldn't write
## to it. Create it root-owned so a new volume starts root-owned:
RUN mkdir -p /app/config
ADD . /app/reloader
RUN cd /app/reloader && npm install
CMD ["/bin/sh", "/app/reloader/start.sh"]
