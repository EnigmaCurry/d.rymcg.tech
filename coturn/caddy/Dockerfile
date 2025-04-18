ARG CADDY_IMAGE
FROM ${CADDY_IMAGE}
RUN apk add --no-cache gettext

ADD Caddyfile.template /etc/caddy/Caddyfile.template
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

ADD index.html /srv/
VOLUME /srv

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
