ARG HOMEPAGE_VERSION
FROM ghcr.io/benphelps/homepage:${HOMEPAGE_VERSION}
WORKDIR /app/reloader
ADD . /app/reloader
RUN npm install
CMD ["/bin/sh", "start.sh"]
