FROM python:3
WORKDIR /usr/src/app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt && \
    apt-get update && \
    apt-get install -y rclone npm && \
    npm install -g tiddlywiki
COPY watcher.py ./
ENV PYTHONUNBUFFERED=1
WORKDIR /tiddlywiki
CMD [ "python", "/usr/src/app/watcher.py" ]
