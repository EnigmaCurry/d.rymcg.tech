ARG VERSION
FROM php:${VERSION}
## Install PHP libraries:
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential libz-dev \
    libpng-dev libjpeg-dev libfreetype-dev libpq-dev autoconf && \
    pecl channel-update pecl.php.net && \
    pecl install redis && \
    docker-php-ext-configure gd --with-jpeg --with-freetype && \
    docker-php-ext-install opcache gd pgsql && \
    docker-php-ext-enable opcache


## PHP config:
COPY php.ini /opt/bitnami/php/etc/conf.d/00_docker_override.ini
ARG DEBUG_MODE
RUN test "${DEBUG_MODE}" == "true" && echo "display_errors = On" > /opt/bitnami/php/etc/conf.d/01_debug_mode.ini || true

## Default PHP index file:
COPY --chmod=0555 phpinfo.php /app/public/index.php
ADD --chmod=0555 https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1-en.php /app/public/adminer.php

WORKDIR /app
VOLUME /app
