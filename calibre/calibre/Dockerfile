ARG CALIBRE_IMAGE
FROM ${CALIBRE_IMAGE}
RUN mkdir /books && chown 1000:1000 /books
VOLUME /books
ADD --chown=1000:1000 --chmod=0600 default_blank_database.db /books/metadata.db
