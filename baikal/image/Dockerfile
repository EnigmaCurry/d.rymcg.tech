# Baikal image builder.
#
# This is a copy of ckulka/baikal-docker's nginx-php8.2.dockerfile
# (https://github.com/ckulka/baikal-docker/blob/master/nginx-php8.2.dockerfile),
# with the Baikal version selectable at build time and the Home Assistant
# CalDAV fix applied at build time. It exists because ckulka's published
# images stop at Baikal 0.10.1.
#
# See README.md in this directory.

# Multi-stage build, see https://docs.docker.com/develop/develop-images/multistage-build/
FROM alpine AS builder

ARG VERSION=0.13.0

# Downloaded with curl rather than ADD so that a stale BAIKAL_VERSION (an image
# tag from an older .env-dist, e.g. 0.10.1-nginx) fails with an actionable
# message instead of an opaque "not found" from the builder.
RUN apk add --no-cache curl unzip && \
    URL="https://github.com/sabre-io/Baikal/releases/download/$VERSION/baikal-$VERSION.zip"; \
    curl -fsSL "$URL" -o baikal.zip || { \
      echo "ERROR: cannot download $URL"; \
      echo "BAIKAL_VERSION must be a Baikal release such as 0.13.0."; \
      echo "Older .env-dist files used it for an image tag such as 0.10.1-nginx;"; \
      echo "set BAIKAL_VERSION=0.13.0 in your .env file and run this again."; \
      exit 1; \
    }; \
    unzip -q baikal.zip

# Final Docker image
FROM nginx:1

# Install dependencies: PHP (with libffi6 dependency) & SQLite3
RUN curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg &&\
  apt update                  &&\
  apt install -y lsb-release  &&\
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list &&\
  apt remove -y lsb-release   &&\
  apt update                  &&\
    apt install -y            \
    php8.2-curl               \
    php8.2-fpm                \
    php8.2-mbstring           \
    php8.2-mysql              \
    php8.2-pgsql              \
    php8.2-sqlite3            \
    php8.2-xml                \
    sqlite3                   \
    msmtp msmtp-mta           &&\
  rm -rf /var/lib/apt/lists/* &&\
  sed -i 's/www-data/nginx/' /etc/php/8.2/fpm/pool.d/www.conf &&\
  sed -i 's/^listen = .*/listen = \/var\/run\/php-fpm.sock/' /etc/php/8.2/fpm/pool.d/www.conf

# Add Baikal & nginx configuration
COPY files/docker-entrypoint.d/*.sh files/docker-entrypoint.d/nginx/ /docker-entrypoint.d/
COPY --from=builder --chown=nginx:nginx baikal /var/www/baikal
COPY files/nginx.conf /etc/nginx/conf.d/default.conf

# Home Assistant CalDAV fix (https://github.com/ckulka/baikal-docker/issues/231,
# https://github.com/sabre-io/dav/issues/1318): Home Assistant sets the
# calendar-timezone property to a bare timezone identifier, which sabre/dav
# tries to parse as a VCALENDAR and fails with "This parser only supports VCARD
# and VCALENDAR files". Use the value directly as a DateTimeZone instead.
# This is the same fix ckulka ships as an opt-in entrypoint script
# (APPLY_HOME_ASSISTANT_FIX), baked into the image instead so it cannot fail at
# container start. Set BAIKAL_HOME_ASSISTANT_FIX=false in .env to build without
# it. The checksums pin the exact upstream file; when VERSION changes, re-check
# the sed below against the new vendor/sabre/dav/lib/CalDAV/Plugin.php and
# update both checksums (the build fails if they do not match).
ARG APPLY_HOME_ASSISTANT_FIX=true
RUN if [ "$APPLY_HOME_ASSISTANT_FIX" = "true" ]; then \
      set -eu; \
      PLUGIN=/var/www/baikal/vendor/sabre/dav/lib/CalDAV/Plugin.php; \
      echo "58b6b2d9da6717ce5d953fc9590f30c9d2edaabf  $PLUGIN" | sha1sum --check --status -; \
      sed -i '511,518c\                $calendarTimeZone = new DateTimeZone($tzResult[$tzProp]);' "$PLUGIN"; \
      echo "b570165f6d7e8caef11250745898df7509e011c3  $PLUGIN" | sha1sum --check --status -; \
    fi

VOLUME /var/www/baikal/config
VOLUME /var/www/baikal/Specific
