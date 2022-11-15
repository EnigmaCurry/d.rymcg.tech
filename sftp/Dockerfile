FROM debian:bullseye-slim as sshd
RUN apt-get update && \
    apt-get -y install openssh-server ssh-import-id libcap2-bin && \
    rm -rf /var/lib/apt/lists/*
VOLUME /etc/ssh
VOLUME /data
COPY entrypoint.sh /usr/local/bin/sshd-entrypoint
COPY create-users.sh /usr/local/bin/create-users
RUN chmod a+x /usr/local/bin/sshd-entrypoint && \
    rm -rf /etc/ssh && \
    mkdir -p /etc/ssh /data && \
    mkdir -p /run/sshd && \
    chmod a+x /usr/local/bin/create-users
COPY sshd_config /etc/ssh/sshd_config
ENTRYPOINT /usr/local/bin/sshd-entrypoint
