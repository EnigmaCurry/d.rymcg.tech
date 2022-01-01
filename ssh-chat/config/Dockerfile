FROM alpine
WORKDIR /root/.ssh
ADD entrypoint.sh /usr/local/bin/entrypoint.sh
RUN apk add openssh && chmod a+x /usr/local/bin/entrypoint.sh

ENTRYPOINT /usr/local/bin/entrypoint.sh
