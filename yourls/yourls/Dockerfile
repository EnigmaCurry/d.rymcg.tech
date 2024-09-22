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
    && docker-php-ext-install -j$(nproc) zip
RUN echo "alias ls='ls -alh --color'" > /root/.bashrc
RUN apt-get clean && rm -rf /var/lib/apt/lists/*