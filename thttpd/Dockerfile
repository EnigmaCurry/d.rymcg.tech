FROM alpine:3
RUN apk add --no-cache thttpd
USER thttpd
WORKDIR /home/thttpd
COPY static/ .
EXPOSE 8000
CMD thttpd -D -h 0.0.0.0 -p 8000 -d /home/thttpd -u thttpd -l - -M ${THTTPD_CACHE_CONTROL}
