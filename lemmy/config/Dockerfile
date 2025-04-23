FROM debian:stable-slim
WORKDIR /template
VOLUME /config
RUN apt-get -y update && apt-get install -y gettext
COPY config.hjson setup.sh config.toml ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
