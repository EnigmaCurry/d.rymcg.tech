FROM debian:stable-slim
RUN apt-get -y update && apt-get install -y openssl gettext
WORKDIR /template
VOLUME /cryptpad/config
COPY config.template.js setup.sh ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
