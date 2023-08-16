ARG WORDPRESS_VERSION
FROM wordpress:${WORDPRESS_VERSION}
ARG WP2STATIC_VERSION
ADD install_composer.sh /tmp/install_composer.sh
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get -y install git
RUN /tmp/install_composer.sh && \
    rm /tmp/install_composer.sh && \
    cd /var/www/html/wp-content/plugins && \
    git clone https://github.com/wp2static/wp2static.git && \
    cd wp2static && \
    git checkout ${WP2STATIC_VERSION} && \
    rm -rf .git && \
    COMPOSER_ALLOW_SUPERUSER=1 composer install && \
    mkdir -p /var/www/html/wp-content/uploads /var/www/static && \
    ln -s /var/www/static /var/www/html/wp-content/uploads/wp2static-processed-site && \
    chown -R www-data:www-data /var/www/html /var/www/static
VOLUME /var/www/html /var/www/static



