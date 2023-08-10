ARG HOMEPAGE_VERSION
FROM ghcr.io/benphelps/homepage:${HOMEPAGE_VERSION}
RUN apk add --no-cache bash openssh git envsubst grep nano
WORKDIR /app
ADD . /app/reloader
RUN cd /app/reloader && npm install
CMD ["/bin/sh", "/app/reloader/start.sh"]
