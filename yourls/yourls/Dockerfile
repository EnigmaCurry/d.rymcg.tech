ARG YOURLS_IMAGE
FROM ${YOURLS_IMAGE:-yourls:1.9.2}
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
RUN mkdir -p /var/www/html/user/plugins/yourls-download-plugin && curl -o /var/www/html/user/plugins/yourls-download-plugin/plugin.php https://raw.githubusercontent.com/krissss/yourls-download-plugin/refs/heads/master/plugin.php
RUN mkdir -p /var/www/html/user/plugins/force-lowercase &&curl -o /var/www/html/user/plugins/force-lowercase/plugin.php https://raw.githubusercontent.com/YOURLS/force-lowercase/refs/heads/master/plugin.php
RUN mkdir -p /var/www/html/user/plugins/yourls-change-password-master && curl -o /var/www/html/user/plugins/yourls-change-password-master/plugin.php https://raw.githubusercontent.com/ozh/yourls-change-password/refs/heads/master/plugin.php
