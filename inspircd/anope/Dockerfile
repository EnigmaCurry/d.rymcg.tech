ARG ANOPE_IMAGE
FROM ${ANOPE_IMAGE}

USER root
RUN apk add --no-cache msmtp ca-certificates \
 && ln -sf /usr/bin/msmtp /usr/sbin/sendmail \
 && ln -sf /data/msmtprc /etc/msmtprc
USER anope
CMD ["/anope/bin/services","-n"]
