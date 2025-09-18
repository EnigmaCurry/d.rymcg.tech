ARG PAIRDROP_IMAGE
FROM ${PAIRDROP_IMAGE}

RUN apk add --no-cache gettext

COPY rtc_config.template.json /etc/pairdrop/rtc_config.template.json
ENV RTC_CONFIG=/etc/pairdrop/rtc_config.json

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/init"]
