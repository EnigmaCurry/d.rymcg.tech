FROM node:alpine
ARG TIDDLYWIKI_NODEJS_VERSION TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION \
    TIDDLYWIKI_NODEJS_SHIRAZ_VERSION TIDDLYWIKI_NODEJS_TRASHBIN_VERSION \
    TIDDLYWIKI_NODEJS_DATEPICKER_VERSION TIDDLYWIKI_NODEJS_MOMENT_VERSION

# https://github.com/nodejs/docker-node/blob/master/docs/BestPractices.md#handling-kernel-signals
RUN apk add --no-cache tini git
RUN npm install -g tiddlywiki@${TIDDLYWIKI_NODEJS_VERSION}

## Install plugins
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/felixhayashi/TW5-TiddlyMap/archive/refs/tags/v${TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION}.zip && \
    unzip v${TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION}.zip && \
    cp -a TW5-TiddlyMap-${TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION}/dist/* /usr/local/lib/node_modules/tiddlywiki/plugins
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
    cp -a TW5-TopStoryView-master/dist/* /usr/local/lib/node_modules/tiddlywiki/plugins
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/sukima/tiddlywiki-reveal-js/archive/master.zip && \
    unzip master.zip && \
    cp -a tiddlywiki-reveal-js-master/plugins/* /usr/local/lib/node_modules/tiddlywiki/plugins && \
    cd /usr/local/lib/node_modules/tiddlywiki && \
    npm install reveal.js
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/kookma/TW-Shiraz/archive/refs/tags/${TIDDLYWIKI_NODEJS_SHIRAZ_VERSION}.zip && \
    unzip ${TIDDLYWIKI_NODEJS_SHIRAZ_VERSION}.zip && \
    mkdir -p /usr/local/lib/node_modules/tiddlywiki/plugins/kookma && \
    cp -a TW-Shiraz-${TIDDLYWIKI_NODEJS_SHIRAZ_VERSION}/source/* /usr/local/lib/node_modules/tiddlywiki/plugins/kookma/
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/kookma/TW-Trashbin/archive/refs/tags/${TIDDLYWIKI_NODEJS_TRASHBIN_VERSION}.zip && \
    unzip ${TIDDLYWIKI_NODEJS_TRASHBIN_VERSION}.zip && \
    mkdir -p /usr/local/lib/node_modules/tiddlywiki/plugins/kookma && \
    cp -a TW-Trashbin-${TIDDLYWIKI_NODEJS_TRASHBIN_VERSION}/source/* /usr/local/lib/node_modules/tiddlywiki/plugins/kookma/
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/kixam/TW5-datePicker/archive/refs/tags/v${TIDDLYWIKI_NODEJS_DATEPICKER_VERSION}.zip && \
    unzip v${TIDDLYWIKI_NODEJS_DATEPICKER_VERSION}.zip && \
    mkdir -p /usr/local/lib/node_modules/tiddlywiki/plugins/kixam && \
    cp -a TW5-datePicker-${TIDDLYWIKI_NODEJS_DATEPICKER_VERSION}/plugins/* \
        /usr/local/lib/node_modules/tiddlywiki/plugins/kixam/
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    git clone --recursive https://github.com/kixam/TW5-moment.js.git && \
    mv TW5-moment.js/plugins/moment /usr/local/lib/node_modules/tiddlywiki/plugins/kixam/