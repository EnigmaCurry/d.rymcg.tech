FROM alpine
ARG POSTGRES_USER
ARG POSTGRES_PASSWORD
ARG JACKAL_KEY
COPY config.template.yaml /config.template.yaml
RUN apk add -U gettext && \
    cat /config.template.yaml | \
    envsubst > /config.yaml && \
    cat /config.yaml

FROM ortuman/jackal:latest
WORKDIR /jackal
ADD https://raw.githubusercontent.com/ortuman/jackal/master/scripts/wait-for-it.sh /jackal/wait-for-it.sh
RUN chmod a+x /jackal/wait-for-it.sh
COPY --from=0 /config.yaml /jackal/config.yaml
