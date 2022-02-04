ARG FROM_IMAGE=lobaro/restic-backup-docker
FROM localhost/
COPY hooks/*.sh /hooks/
RUN chmod a+x /hooks/*.sh

### Database backup dependencies:

RUN apk update \
	&& apk add coreutils \
	&& apk add postgresql14-client \
	&& apk add openssl \
	&& rm -rf /var/cache/apk/*

ENV POSTGRES_DATABASE **None**
ENV POSTGRES_HOST **None**
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER **None**
ENV POSTGRES_PASSWORD **None**
ENV POSTGRES_EXTRA_OPTS ''

ENV AWS_ACCESS_KEY_ID **None**
ENV AWS_SECRET_ACCESS_KEY **None**
ENV S3_BUCKET **None**
ENV S3_PREFIX 'backup'
ENV S3_ENDPOINT **None**
ENV ENCRYPTION_PASSWORD **None**
ENV DELETE_OLDER_THAN **None**

