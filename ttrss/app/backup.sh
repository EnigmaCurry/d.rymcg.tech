#!/bin/sh -e

DST_DIR=/backups
KEEP_DAYS=28
APP_ROOT=/var/www/html/tt-rss

if pg_isready -h $TTRSS_DB_HOST -U $TTRSS_DB_USER; then
	DST_FILE=ttrss-backup-$(date +%Y%m%d).sql.gz

	echo backing up tt-rss database to $DST_DIR/$DST_FILE...

	export PGPASSWORD=$TTRSS_DB_PASS 

	pg_dump --clean -h $TTRSS_DB_HOST -U $TTRSS_DB_USER $TTRSS_DB_NAME | gzip > $DST_DIR/$DST_FILE

	DST_FILE=ttrss-backup-$(date +%Y%m%d).tar.gz

	echo backing up tt-rss local directories to $DST_DIR/$DST_FILE...

	tar -cz -f $DST_DIR/$DST_FILE $APP_ROOT/*.local \
		$APP_ROOT/feed-icons/ \
		$APP_ROOT/config.php

	echo cleaning up...

	find $DST_DIR -type f -name '*.gz' -mtime +$KEEP_DAYS -delete

	echo done.
else
	echo backup failed: database is not ready.
fi
