ARG TRILIUMNEXT_NOTES_IMAGE
FROM ${TRILIUMNEXT_NOTES_IMAGE}
WORKDIR /template
RUN apk add --no-cache gettext
COPY setup.sh config.ini ./
RUN chmod a+x /template/setup.sh
CMD ["/bin/sh", "/template/setup.sh"]
