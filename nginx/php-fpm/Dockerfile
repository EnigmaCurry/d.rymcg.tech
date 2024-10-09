ARG VERSION
FROM php:${VERSION}
## Install PHP libraries:
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential libz-dev \
    libpng-dev libjpeg-dev libfreetype-dev libpq-dev autoconf && \
    pecl channel-update pecl.php.net && \
    pecl install redis && \
    docker-php-ext-configure gd --with-jpeg --with-freetype && \
    docker-php-ext-install opcache gd pgsql pdo_pgsql && \
    docker-php-ext-enable opcache


## PHP config:
COPY php.ini /opt/bitnami/php/etc/conf.d/00_docker_override.ini
ARG DEBUG_MODE
RUN test "${DEBUG_MODE}" == "true" && echo "display_errors = On" > /opt/bitnami/php/etc/conf.d/01_debug_mode.ini || true

## Default PHP index file:
ARG PHP_INDEX_FILE=default.php
ADD --chmod=0555 ${PHP_INDEX_FILE} /app/public/index.php

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]

WORKDIR /app
VOLUME /app
