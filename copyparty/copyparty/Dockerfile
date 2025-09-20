ARG COPYPARTY_IMAGE

FROM ${COPYPARTY_IMAGE}
RUN apk add -U bash

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
