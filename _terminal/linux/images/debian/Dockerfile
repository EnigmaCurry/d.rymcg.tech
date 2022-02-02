ARG FROM=docker.io/debian:bullseye
FROM ${FROM}

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y sudo git build-essential && \
    groupadd wheel && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheelers