#!/bin/bash

set -e
error(){ echo "Error: $@" >/dev/stderr; }
fault(){ test -n "$1" && error $1; echo "Exiting." >/dev/stderr; exit 1; }

if [[ "${POSTGRES_MAINTAINANCE_MODE}" == "true" ]]; then
    exit 0
fi

set -x
pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
pgrep -fa 'tinycron.*backup_cron_local_diff' || fault "job backup_cron_local_diff not running"
pgrep -fa 'tinycron.*backup_cron_local_full' || fault "job backup_cron_local_full not running"
pgrep -fa 'tinycron.*backup_cron_s3_diff' || fault "job backup_cron_s3_diff not running"
pgrep -fa 'tinycron.*backup_cron_s3_full' || fault "job backup_cron_s3_full not running"

echo "Healthcheck passed."
