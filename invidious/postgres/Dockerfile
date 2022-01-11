FROM postgres:10

RUN apt-get update && \
    apt-get install -y git && \
    git clone --depth 1 https://github.com/iv-org/invidious.git /usr/local/src/invidious && \
    cp -r /usr/local/src/invidious/config /config && \
    cp /usr/local/src/invidious/docker/init-invidious-db.sh /docker-entrypoint-initdb.d/ && \
    rm -rf /usr/local/src/invidious && \
    apt-get remove -y git

