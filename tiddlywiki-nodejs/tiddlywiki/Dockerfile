FROM node:alpine
ARG TIDDLYWIKI_NODEJS_VERSION=5.2.3

# https://github.com/nodejs/docker-node/blob/master/docs/BestPractices.md#handling-kernel-signals
RUN apk add --no-cache tini
RUN npm install -g tiddlywiki@${TIDDLYWIKI_NODEJS_VERSION}

EXPOSE 8080
VOLUME /tiddlywiki
WORKDIR /tiddlywiki
COPY tiddlywiki.info /tiddlywiki/tiddlywiki.info
ENTRYPOINT ["/sbin/tini", "--", "tiddlywiki"]
CMD ["--help"]
