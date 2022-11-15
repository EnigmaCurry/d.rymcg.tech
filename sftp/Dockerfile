FROM debian:bullseye-slim as sshd
RUN apt-get update && \
    apt-get -y install openssh-server ssh-import-id

FROM sshd
ARG SFTP_SSHD_UID SFTP_SSHD_GID
VOLUME /home/sshd-user/ssh
VOLUME /home/sshd-user/data
COPY entrypoint.sh /usr/local/bin/sshd-entrypoint
RUN apt-get update && \
    apt-get -y install openssh-server ssh-import-id && \
    rm -rf /var/lib/apt/lists/* && \
    chmod a+x /usr/local/bin/sshd-entrypoint && \
    groupadd -g ${SFTP_SSHD_GID} sshd-user && \
    useradd -m -g ${SFTP_SSHD_GID} -u ${SFTP_SSHD_UID} sshd-user && \
    mkdir -p /home/sshd-user/ssh/keys /home/sshd-user/ssh/data && \
    chown -R sshd-user:sshd-user /home/sshd-user/ssh
COPY sshd_config /home/sshd-user/ssh/sshd_config
ENTRYPOINT /usr/local/bin/sshd-entrypoint
