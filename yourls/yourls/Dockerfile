ARG YOURLS_IMAGE
FROM ${YOURLS_IMAGE:-yourls:1.9.2}
ARG YOURLS_PLUGIN_CHANGE_PASSWORD_PACKAGE_DIST YOURLS_PLUGIN_FORCE_LOWERCASE_PACKAGE_DIST YOURLS_PLUGIN_DOWNLOAD_PLUGIN_PACKAGE_DIST
RUN apt-get update && apt-get install -y \
		libfreetype-dev \
		libjpeg62-turbo-dev \
		libpng-dev \
        libzip-dev \
        unzip \
        micro \
    && docker-php-ext-configure zip \
    && docker-php-ext-install -j$(nproc) zip \
	&& apt-get clean && rm -rf /var/lib/apt/lists/*
RUN echo "value: ${YOURLS_PLUGIN_DOWNLOAD_PLUGIN_PACKAGE_DIST}"
RUN mkdir -p /var/www/html/user/plugins/yourls-download-plugin && curl -o /var/www/html/user/plugins/yourls-download-plugin/plugin.php ${YOURLS_PLUGIN_DOWNLOAD_PLUGIN_PACKAGE_DIST}
RUN mkdir -p /var/www/html/user/plugins/force-lowercase && curl -o /var/www/html/user/plugins/force-lowercase/plugin.php ${YOURLS_PLUGIN_FORCE_LOWERCASE_PACKAGE_DIST}
RUN mkdir -p /var/www/html/user/plugins/yourls-change-password-master && curl -o /var/www/html/user/plugins/yourls-change-password-master/plugin.php ${YOURLS_PLUGIN_CHANGE_PASSWORD_PACKAGE_DIST}
