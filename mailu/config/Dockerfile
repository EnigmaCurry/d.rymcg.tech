FROM debian:stable-slim
WORKDIR /template
VOLUME /overrides/postfix
RUN apt-get -y update && apt-get install -y gettext
COPY overrides/ setup.sh ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
