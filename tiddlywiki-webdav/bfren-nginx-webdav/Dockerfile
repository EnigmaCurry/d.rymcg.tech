FROM bfren/nginx-webdav
ARG TIDDLYWIKI_IMPORT_URL=https://tiddlywiki.com/empty.html

ENV WEBDAV_ACCESS="rw" WEBDAV_METHODS="PUT DELETE MKCOL COPY MOVE" WEBDAV_EXT_METHODS="PROPFIND OPTIONS"
RUN chown www:www /www
ADD --chown=www:www ${TIDDLYWIKI_IMPORT_URL} /www/index.html
VOLUME /www
