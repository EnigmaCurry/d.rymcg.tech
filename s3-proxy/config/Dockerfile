FROM debian:stable-slim
WORKDIR /template
VOLUME /proxy/conf
RUN apt-get -y update && apt-get install -y gettext
COPY s3-proxy.template.yml setup.sh ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
