FROM node:alpine
ARG TIDDLYWIKI_NODEJS_VERSION
ARG TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION

# https://github.com/nodejs/docker-node/blob/master/docs/BestPractices.md#handling-kernel-signals
RUN apk add --no-cache tini
RUN npm install -g tiddlywiki@${TIDDLYWIKI_NODEJS_VERSION}

## Install plugins
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/felixhayashi/TW5-TiddlyMap/archive/refs/tags/v${TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION}.zip && \
    unzip v${TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION}.zip && \
    cp -a TW5-TiddlyMap-0.17.15/dist/* /usr/local/lib/node_modules/tiddlywiki/plugins
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/flibbles/tw5-vis-network/archive/refs/heads/master.zip && \
    unzip master.zip && \
    cp -a tw5-vis-network-master/plugins/* /usr/local/lib/node_modules/tiddlywiki/plugins
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/felixhayashi/TW5-HotZone/archive/refs/heads/master.zip && \
    unzip master.zip && \
    cp -a TW5-HotZone-master/dist/* /usr/local/lib/node_modules/tiddlywiki/plugins
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/felixhayashi/TW5-TopStoryView/archive/refs/heads/master.zip && \
    unzip master.zip && \
    cp -a TW5-TopStoryView-master/dist/* /usr/local/lib/node_modules/tiddlywiki/plugin
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/sukima/tiddlywiki-reveal-js/archive/master.zip && \
    unzip master.zip && \
    cp -a tiddlywiki-reveal-js-master/plugins/* /usr/local/lib/node_modules/tiddlywiki/plugins && \
    cd /usr/local/lib/node_modules/tiddlywiki && \
    npm install reveal.js
