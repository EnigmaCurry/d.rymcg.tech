FROM debian:bullseye-slim as sshd
RUN apt-get update && \
    apt-get -y install openssh-server ssh-import-id

FROM sshd
ARG SFTP_SSHD_UID SFTP_SSHD_GID
RUN apt-get update && \
    apt-get -y install openssh-server ssh-import-id && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g ${SFTP_SSHD_GID} sshd-user && \
    useradd -m -g ${SFTP_SSHD_GID} -u ${SFTP_SSHD_UID} sshd-user
USER sshd-user
RUN mkdir -p /home/sshd-user/ssh/keys
COPY sshd_config /home/sshd-user/ssh/sshd_config
VOLUME /home/sshd-user/ssh/keys
VOLUME /home/sshd-user/data
CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/home/sshd-user/ssh/sshd_config"]
