FROM debian:bullseye-slim
RUN apt-get update && \
    apt-get install -y inotify-tools git ssh && \
    adduser --gecos GECOS --disabled-password git-user && \
    mkdir -p /home/git-user/.ssh /git && \
    chown git-user:git-user /home/git-user/.ssh /git
COPY git-autocommit.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh
USER git-user
WORKDIR /home/git-user
ENTRYPOINT ["/entrypoint.sh"]
