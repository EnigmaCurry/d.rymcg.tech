FROM bfren/nginx-webdav
ENV WEBDAV_ACCESS="rw" WEBDAV_METHODS="PUT DELETE MKCOL COPY MOVE" WEBDAV_EXT_METHODS="PROPFIND OPTIONS"
RUN chown www:www /www
ADD --chown=www:www https://tiddlywiki.com/empty.html /www/index.html
VOLUME /www
