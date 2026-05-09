ARG STEP_CLI_IMAGE
FROM ${STEP_CLI_IMAGE}
USER root

# Determine the correct architecture and download the appropriate gosu binary
# https://github.com/tianon/gosu
RUN apk add --no-cache wget jq gpg gpg-agent && \
    gpg --batch --no-tty --keyserver hkps://keys.openpgp.org \
    --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    arch=$(apk --print-arch) && \
    case "$arch" in \
        x86_64)   dpkg_arch="amd64" ;; \
        aarch64)  dpkg_arch="arm64" ;; \
        armv7)    dpkg_arch="armhf" ;; \
        armv6)    dpkg_arch="armel" ;; \
        x86)      dpkg_arch="i386" ;; \
        *)        echo "Unsupported architecture: $arch" && exit 1 ;; \
    esac && \
    gosu_url=$(wget -qO- "https://api.github.com/repos/tianon/gosu/releases/latest" | \
    jq -r --arg arch "gosu-${dpkg_arch}" '.assets[] | select(.name == $arch) | .browser_download_url') && \
    echo "Downloading: $gosu_url" && \
    wget -q -O /usr/local/bin/gosu "$gosu_url" || (echo "Failed to download gosu from $gosu_url" && exit 1) && \
    wget -q -O /usr/local/bin/gosu.asc "${gosu_url}.asc" || (echo "Failed to download signature" && exit 1) && \
    gpg --batch --no-tty --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    chmod +x /usr/local/bin/gosu && \
    gosu --version

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 entrypoint-user.sh /usr/local/bin/entrypoint-user.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
