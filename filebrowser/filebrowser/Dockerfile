ARG IMAGE
FROM ${IMAGE}

RUN apk add -U bash
ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT /entrypoint.sh
