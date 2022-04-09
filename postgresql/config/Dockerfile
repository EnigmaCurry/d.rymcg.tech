ARG STEPCA_VERSION=0.18.2
FROM smallstep/step-ca:${STEPCA_VERSION}
USER root
RUN apk add -U gettext openssl
WORKDIR /template
VOLUME /config
COPY postgresql.conf pg_hba.conf setup.sh ./
RUN chmod a+x setup.sh
CMD ["./setup.sh"]
