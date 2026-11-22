FROM alpine:3
RUN apk add --no-cache tor python3
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN mkdir -p /var/lib/tor && chown -R tor:tor /var/lib/tor && chmod 700 /var/lib/tor
USER tor
ENTRYPOINT ["/entrypoint.sh"]
