FROM alpine:3
ARG THTTPD_UID
RUN apk add --no-cache thttpd
WORKDIR /home/web
COPY static/ .
RUN adduser -D -u ${THTTPD_UID} -h /home/web web && \
    chown -R web .
VOLUME /home/web
EXPOSE 8000
CMD thttpd -D -h 0.0.0.0 -p 8000 -d /home/web -u web -l -
