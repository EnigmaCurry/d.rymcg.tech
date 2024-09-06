FROM debian:stable-slim
WORKDIR /template
VOLUME /config
RUN apt-get -y update && apt-get install -y gettext
COPY settings.yml limiter.toml setup.sh ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
