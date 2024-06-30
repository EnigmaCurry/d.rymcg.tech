ARG NEXTCLOUD_IMAGE
FROM ${NEXTCLOUD_IMAGE:-nextcloud:apache}
RUN export DEBIAN_FRONTEND=noninteractive; \
    apt-get update && \
    apt-get install -y ffmpeg
