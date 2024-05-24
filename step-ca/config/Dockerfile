ARG IMAGE
FROM ${IMAGE}
USER root
RUN apk add -U jq
WORKDIR /config
COPY setup.sh ./
RUN chmod a+x setup.sh
USER step
ENTRYPOINT /config/setup.sh
