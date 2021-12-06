FROM debian:stable-slim
WORKDIR /template
VOLUME /config
RUN apt-get -y update && apt-get install -y gettext
COPY config.template.yaml config.template.yaml
COPY create-config.sh create-config.sh
RUN chmod a+x create-config.sh
CMD ["./create-config.sh"]
