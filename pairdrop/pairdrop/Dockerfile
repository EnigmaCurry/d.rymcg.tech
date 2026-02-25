ARG PAIRDROP_IMAGE
FROM ${PAIRDROP_IMAGE}

RUN apk add --no-cache gettext openssl

COPY rtc_config.template.json /etc/pairdrop/rtc_config.template.json
ENV RTC_CONFIG=/etc/pairdrop/rtc_config.json

# Mint helper + s6 hooks
COPY --chmod=0755 usr/local/bin/mint /usr/local/bin/mint
COPY --chmod=0755 etc/cont-init.d/10-rtc-config /etc/cont-init.d/10-rtc-config
COPY --chmod=0755 etc/services.d/rtc-rotate/run /etc/services.d/rtc-rotate/run
