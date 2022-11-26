FROM python:3
ARG TIDDLYWIKI_VERSION=5.2.3
WORKDIR /usr/src
COPY requirements.txt ./
COPY watcher.py ./app/watcher.py
RUN pip install --no-cache-dir -r requirements.txt && \
    apt-get update && \
    apt-get install -y rclone npm && \
    wget https://github.com/Jermolene/TiddlyWiki5/archive/refs/tags/v${TIDDLYWIKI_VERSION}.tar.gz && \
    tar xfv v${TIDDLYWIKI_VERSION}.tar.gz && \
    rm v${TIDDLYWIKI_VERSION}.tar.gz && \
    cd TiddlyWiki5-${TIDDLYWIKI_VERSION} && \
    npm install && \
    npm link
ENV PYTHONUNBUFFERED=1
WORKDIR /tiddlywiki
CMD [ "python", "/usr/src/app/watcher.py" ]
