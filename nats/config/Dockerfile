FROM debian:stable-slim
RUN apt-get -y update && apt-get install -y gettext
COPY template/ /template/
COPY setup.sh /template/setup.sh
RUN chmod a+x /template/setup.sh
CMD ["/template/setup.sh"]
