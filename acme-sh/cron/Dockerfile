ARG GIT_TAG
FROM local/acme-sh-base-image:${GIT_TAG}

ARG CRON_SCHEDULE="0 * * * *"
RUN echo "${CRON_SCHEDULE} /root/.acme.sh/acme.sh --cron --home /root/.acme.sh --config-home /acme.sh --cert-home /certs > /proc/1/fd/1 2>/proc/1/fd/2" > /etc/crontabs/root
