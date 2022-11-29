FROM debian:stable-slim as ytt
ARG TIDDLYWIKI_NODEJS_CONFIG_YTT_VERSION
RUN apt update && apt install -y jq wget && wget "https://github.com/vmware-tanzu/carvel-ytt/releases/download/${TIDDLYWIKI_NODEJS_CONFIG_YTT_VERSION}/ytt-linux-$(dpkg --print-architecture)" -O ytt && install ytt /usr/local/bin/ytt

FROM ytt
ARG TIDDLYWIKI_NODEJS_PLUGINS
WORKDIR /template
COPY setup.sh tiddlywiki.info.yaml ./
RUN chmod a+x setup.sh
VOLUME /config
CMD ["./setup.sh"]
