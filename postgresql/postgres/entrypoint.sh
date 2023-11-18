#!/bin/bash

set -mex

default_startup() {
    ## Create backup scripts scheduled via tinycron:
    cat <<EOF > /var/lib/postgresql/backup_cron_local_full.sh
#!/usr/local/bin/tinycron ${POSTGRES_PGBACKREST_LOCAL_SCHEDULE_FULL} /bin/sh
set -x; pgbackrest --stanza=apps --log-level-console=info --annotation=postgres-host=${POSTGRES_HOST} --annotation=instance=${POSTGRES_INSTANCE} backup --repo=1 --type=full
EOF
    cat <<EOF > /var/lib/postgresql/backup_cron_local_diff.sh
#!/usr/local/bin/tinycron ${POSTGRES_PGBACKREST_LOCAL_SCHEDULE_DIFF} /bin/sh
set -x; pgbackrest --stanza=apps --log-level-console=info --annotation=postgres-host=${POSTGRES_HOST} --annotation=instance=${POSTGRES_INSTANCE} backup --repo=1 --type=diff
EOF
    cat <<EOF > /var/lib/postgresql/backup_cron_s3_full.sh
#!/usr/local/bin/tinycron ${POSTGRES_PGBACKREST_S3_SCHEDULE_FULL} /bin/sh
set -x; pgbackrest --stanza=apps --log-level-console=info --annotation=postgres-host=${POSTGRES_HOST} --annotation=instance=${POSTGRES_INSTANCE} backup --repo=2 --type=full
EOF
    cat <<EOF > /var/lib/postgresql/backup_cron_s3_diff.sh
#!/usr/local/bin/tinycron ${POSTGRES_PGBACKREST_S3_SCHEDULE_DIFF} /bin/sh
set -x; pgbackrest --stanza=apps --log-level-console=info --annotation=postgres-host=${POSTGRES_HOST} --annotation=instance=${POSTGRES_INSTANCE} backup --repo=2 --type=diff
EOF
    chmod 0555 /var/lib/postgresql/backup_cron*.sh

    ## Drop privileges to run backup schedulers as the postgres user in the background:
    TINYCRON_VERBOSE=true setuidgid postgres /var/lib/postgresql/backup_cron_local_full.sh &
    TINYCRON_VERBOSE=true setuidgid postgres /var/lib/postgresql/backup_cron_local_diff.sh &
    TINYCRON_VERBOSE=true setuidgid postgres /var/lib/postgresql/backup_cron_s3_full.sh &
    TINYCRON_VERBOSE=true setuidgid postgres /var/lib/postgresql/backup_cron_s3_diff.sh &

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
