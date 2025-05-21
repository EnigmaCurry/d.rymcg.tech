ARG IMAGE
FROM ${IMAGE}

RUN apk add -U bash su-exec
ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
