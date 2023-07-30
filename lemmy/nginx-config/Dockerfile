FROM debian:stable-slim
WORKDIR /template
VOLUME /etc/nginx
RUN apt-get -y update && apt-get install -y gettext
COPY nginx_internal.conf setup.sh ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
