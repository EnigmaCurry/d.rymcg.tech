FROM bfren/nginx-webdav
ARG WWW_UID=1000 WWW_GID=1000
RUN apk --no-cache add shadow && \
    usermod -u ${WWW_UID} www && \
    groupmod -g ${WWW_GID} www && \
    chown -R www:www /www
VOLUME /www
