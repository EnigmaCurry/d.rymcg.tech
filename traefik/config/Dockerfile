FROM debian:13-slim AS ytt
ARG TRAEFIK_CONFIG_YTT_VERSION
RUN apt update && apt install -y wget && wget "https://github.com/vmware-tanzu/carvel-ytt/releases/download/${TRAEFIK_CONFIG_YTT_VERSION}/ytt-linux-$(dpkg --print-architecture)" -O ytt && install ytt /usr/local/bin/ytt

FROM ytt
WORKDIR /template
COPY setup.sh traefik.yml config-template ./
COPY context-template ./context-template
RUN chmod a+x setup.sh && mkdir /data
VOLUME /config
CMD ["./setup.sh"]
