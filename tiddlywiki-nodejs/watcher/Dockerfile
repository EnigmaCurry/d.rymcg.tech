FROM python:3
ARG TIDDLYWIKI_NODEJS_VERSION
ARG TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION

WORKDIR /usr/src
RUN apt-get update && \
    apt-get install -y rclone npm exiftool libgirepository1.0-dev gir1.2-poppler-0.18 && \
    wget https://github.com/Jermolene/TiddlyWiki5/archive/refs/tags/v${TIDDLYWIKI_NODEJS_VERSION}.tar.gz && \
    tar xfv v${TIDDLYWIKI_NODEJS_VERSION}.tar.gz && \
    rm v${TIDDLYWIKI_NODEJS_VERSION}.tar.gz && \
    cd TiddlyWiki5-${TIDDLYWIKI_NODEJS_VERSION} && \
    npm install && \
    npm link

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
    cp -a TW5-TopStoryView-master/dist/* /usr/local/lib/node_modules/tiddlywiki/plugins
RUN TMP_DIR=$(mktemp -d) && cd ${TMP_DIR} && \
    wget https://github.com/sukima/tiddlywiki-reveal-js/archive/master.zip && \
    unzip master.zip && \
    cp -a tiddlywiki-reveal-js-master/plugins/* /usr/local/lib/node_modules/tiddlywiki/plugins && \
    cd /usr/local/lib/node_modules/tiddlywiki && \
    npm install reveal.js


COPY requirements.txt ./
RUN pip install --no-cache-dir -r /usr/src/requirements.txt
COPY watcher.py /usr/src/app/watcher.py
ENV PYTHONUNBUFFERED=1
WORKDIR /tiddlywiki
CMD [ "python", "/usr/src/app/watcher.py" ]
