FROM debian:stable-slim
WORKDIR /template
RUN apt-get -y update && apt-get install -y openssl gettext
COPY template/* setup.sh ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
