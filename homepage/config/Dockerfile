FROM debian:stable-slim
WORKDIR /test
VOLUME /app/config
RUN apt-get -y update && apt-get install -y gettext
#COPY services.yaml bookamrks.yaml docker.yaml settings.yaml widgets.yaml ./
COPY services.yaml /test/
