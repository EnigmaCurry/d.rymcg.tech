FROM alpine:3
COPY watcher.sh /usr/local/bin/watcher
RUN apk --no-cache add bash inotify-tools rclone && \
    chmod a+x /usr/local/bin/watcher
ENTRYPOINT ["/bin/bash", "/usr/local/bin/watcher"]
