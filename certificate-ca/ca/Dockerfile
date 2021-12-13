FROM debian:stable-slim
VOLUME /CA
RUN apt-get update -y && apt-get install -y openssl

COPY ca.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/ca.sh
ENTRYPOINT ["/usr/local/bin/ca.sh"]
