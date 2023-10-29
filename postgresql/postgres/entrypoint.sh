#!/bin/bash

set -mex

default_startup() {
    ## Create backup scripts scheduled via tinycron:
    cat <<EOF > /var/lib/postgresql/backup_cron_local.sh
#!/usr/local/bin/tinycron ${POSTGRES_PGBACKREST_LOCAL_SCHEDULE} /bin/sh
echo "Current time: \$(date)" > /tmp/local.txt
EOF
    cat <<EOF > /var/lib/postgresql/backup_cron_s3.sh
#!/usr/local/bin/tinycron ${POSTGRES_PGBACKREST_S3_SCHEDULE} /bin/sh
echo "Current time: \$(date)" > /tmp/s3.txt
EOF
    chmod 0555 /var/lib/postgresql/backup_cron*.sh

    ## Drop privileges to run backup schedulers as the postgres user in the background:
    TINYCRON_VERBOSE=true setuidgid postgres /var/lib/postgresql/backup_cron_local.sh &
    TINYCRON_VERBOSE=true setuidgid postgres /var/lib/postgresql/backup_cron_s3.sh &

    ## Run the original postgres docker entrypoint:
    /usr/local/bin/docker-entrypoint.sh postgres -c 'config_file=/etc/postgresql/postgresql.conf'
}

maintainance_mode() {
    echo "## Starting in maintainance mode. Postgres and tinycron are stopped."
    sleep infinity
}

if [[ "${POSTGRES_MAINTAINANCE_MODE}" == "true" ]]; then
    maintainance_mode
elif [[ "$#" == "0" ]]; then
    default_startup
else
    echo "## Starting with custom command:"
    $@
fi
