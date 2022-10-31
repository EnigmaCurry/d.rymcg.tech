FROM debian:stable-slim as ytt
ARG TRAEFIK_CONFIG_YTT_VERSION
ARG TRAEFIK_CONFIG_YTT_ARCH
RUN apt update && apt install -y wget && wget "https://github.com/vmware-tanzu/carvel-ytt/releases/download/${TRAEFIK_CONFIG_YTT_VERSION}/ytt-linux-${TRAEFIK_CONFIG_YTT_ARCH}" -O ytt && install ytt /usr/local/bin/ytt

FROM ytt
WORKDIR /template
VOLUME /config
COPY config-template/* user-template/* setup.sh ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
