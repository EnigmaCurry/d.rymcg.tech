FROM debian:stable-slim as ytt
ARG ONLYOFFICE_CONFIG_YTT_VERSION
RUN apt update && apt install -y wget && wget "https://github.com/vmware-tanzu/carvel-ytt/releases/download/${ONLYOFFICE_CONFIG_YTT_VERSION}/ytt-linux-$(dpkg --print-architecture)" -O ytt && install ytt /usr/local/bin/ytt

FROM ytt
WORKDIR /template
VOLUME /config
COPY setup.sh setup.sql onlyoffice.cnf ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
