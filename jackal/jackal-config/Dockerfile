FROM debian:stable-slim
WORKDIR /template
VOLUME /config
RUN apt-get -y update && apt-get install -y openssl gettext
COPY config.template.yaml config.template.yaml
COPY setup.sh setup.sh
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
