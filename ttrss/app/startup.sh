#!/bin/sh -e

while ! pg_isready -h $TTRSS_DB_HOST -U $TTRSS_DB_USER; do
	echo waiting until $TTRSS_DB_HOST is ready...
	sleep 3
done

# We don't need those here (HTTP_HOST would cause false SELF_URL_PATH check failures)
unset HTTP_PORT
unset HTTP_HOST

if ! id app >/dev/null 2>&1; then
	addgroup -g $OWNER_GID app
	adduser -D -h /var/www/html -G app -u $OWNER_UID app
fi

DST_DIR=/var/www/html/tt-rss
SRC_REPO=https://git.tt-rss.org/fox/tt-rss.git

[ -e $DST_DIR ] && rm -f $DST_DIR/.app_is_ready

export PGPASSWORD=$TTRSS_DB_PASS 

[ ! -e /var/www/html/index.php ] && cp ${SCRIPT_ROOT}/index.php /var/www/html

PSQL="psql -q -h $TTRSS_DB_HOST -U $TTRSS_DB_USER $TTRSS_DB_NAME"

if [ ! -d $DST_DIR/.git ]; then
	mkdir -p $DST_DIR
	echo cloning tt-rss source from $SRC_REPO to $DST_DIR...
	git clone $SRC_REPO $DST_DIR || echo error: failed to clone master repository.
else
	echo updating tt-rss source in $DST_DIR from $SRC_REPO...
	cd $DST_DIR && \
		git config core.filemode false && \
		git config pull.rebase false && \
		git pull origin master || echo error: unable to update master repository.
fi

if [ ! -e $DST_DIR/index.php ]; then
	echo "error: tt-rss index.php missing (git clone failed?), unable to continue."
	exit 1
fi

if [ ! -d $DST_DIR/plugins.local/nginx_xaccel ]; then
	echo cloning plugins.local/nginx_xaccel...
	git clone https://git.tt-rss.org/fox/ttrss-nginx-xaccel.git \
		$DST_DIR/plugins.local/nginx_xaccel ||  echo error: failed to clone plugin repository.
else
	echo updating plugins.local/nginx_xaccel...
	cd $DST_DIR/plugins.local/nginx_xaccel && \
		git config core.filemode false && \
		git config pull.rebase false && \
	  	git pull origin master || echo error: failed to update plugin repository.
fi

cp ${SCRIPT_ROOT}/config.docker.php $DST_DIR/config.php
chmod 644 $DST_DIR/config.php

chown -R $OWNER_UID:$OWNER_GID $DST_DIR \
	/var/log/php8

for d in cache lock feed-icons; do
	chmod 777 $DST_DIR/$d
	find $DST_DIR/$d -type f -exec chmod 666 {} \;
done

$PSQL -c "create extension if not exists pg_trgm"

RESTORE_SCHEMA=${SCRIPT_ROOT}/restore-schema.sql.gz

if [ -r $RESTORE_SCHEMA ]; then
	$PSQL -c "drop schema public cascade; create schema public;"
	zcat $RESTORE_SCHEMA | $PSQL
fi

# this was previously generated
rm -f $DST_DIR/config.php.bak

if [ ! -z "${TTRSS_XDEBUG_ENABLED}" ]; then
	if [ -z "${TTRSS_XDEBUG_HOST}" ]; then
		export TTRSS_XDEBUG_HOST=$(ip ro sh 0/0 | cut -d " " -f 3)
	fi
	echo enabling xdebug with the following parameters:
	env | grep TTRSS_XDEBUG
	cat > /etc/php8/conf.d/50_xdebug.ini <<EOF
zend_extension=xdebug.so
xdebug.mode=develop,trace,debug
xdebug.start_with_request = yes
xdebug.client_port = ${TTRSS_XDEBUG_PORT}
xdebug.client_host = ${TTRSS_XDEBUG_HOST}
EOF
fi

cd $DST_DIR && sudo -E -u app php8 ./update.php --update-schema=force-yes

rm -f /tmp/error.log && mkfifo /tmp/error.log && chown app:app /tmp/error.log

(tail -q -f /tmp/error.log >> /proc/1/fd/2) &

touch $DST_DIR/.app_is_ready

exec /usr/sbin/php-fpm8 --nodaemonize --force-stderr
