FROM python:3
ARG TIDDLYWIKI_NODEJS_VERSION
ARG TIDDLYWIKI_NODEJS_TIDDLYMAP_VERSION

RUN apt-get update && \
    apt-get install -y rclone npm exiftool libgirepository1.0-dev gir1.2-poppler-0.18

COPY --from=tiddlywiki-nodejs-base /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY requirements.txt /usr/src

RUN ln -s /usr/local/lib/node_modules/tiddlywiki/tiddlywiki.js /usr/local/bin/tiddlywiki && \
    pip install --no-cache-dir -r /usr/src/requirements.txt
COPY watcher.py /usr/src/app/watcher.py
ENV PYTHONUNBUFFERED=1
WORKDIR /tiddlywiki
CMD [ "python", "/usr/src/app/watcher.py" ]
