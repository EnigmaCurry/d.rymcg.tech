FROM alpine:3
USER root
RUN apk add -U jq bash
WORKDIR /config
COPY setup.sh ./
RUN chmod a+x setup.sh
ENTRYPOINT /config/setup.sh
