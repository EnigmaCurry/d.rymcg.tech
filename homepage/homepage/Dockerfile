ARG HOMEPAGE_IMAGE
FROM ${HOMEPAGE_IMAGE}
RUN apk add --no-cache bash openssh git envsubst grep rsync
WORKDIR /app
## The config volume is mounted at both /app/config and /app/public/images.
## A new, empty volume takes the ownership of whichever mountpoint first has
## content to copy in: upstream v2.8 ships no /app/config and a node-owned
## (uid 1000) /app/public/images, so the volume came up owned by 1000. The
## reloader runs as root with all capabilities dropped and couldn't write to
## it. Make both mountpoints root-owned so a new volume starts root-owned:
RUN mkdir -p /app/config && chown -R root:root /app/public/images
ADD . /app/reloader
RUN cd /app/reloader && npm install
CMD ["/bin/sh", "/app/reloader/start.sh"]
