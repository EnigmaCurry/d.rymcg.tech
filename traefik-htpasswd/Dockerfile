FROM alpine
ADD traefik-htpasswd.sh /usr/local/bin/
RUN apk add -U bash openssl python3 apache2-utils && \
    chmod a+x /usr/local/bin/traefik-htpasswd.sh
CMD /usr/local/bin/traefik-htpasswd.sh
