set -e

check_vars() {
    EXIT=false
    for var in "$@"; do
        test -z ${!var} && echo "Must set ${var}" && EXIT=true
    done
    if [[ ${EXIT} == true ]]; then exit 1; fi
}

check_vars POSTGRES_DATABASE \
           POSGRES_HOST \
           POSTGRES_PORT \
           POSTGRES_USER \
           POSTGRES_PASSWORD \
           POSTGRES_EXTRA_OPTS \
           AWS_ACCESS_KEY_ID \
           AWS_SECRET_ACCESS_KEY \
           S3_BUCKET \
           S3_PREFIX \
           S3_ENDPOINT \
           ENCRYPTION_PASSWORD \
           DATABASE_BACKUP_DELETE_OLDER_THAN

POSTGRES_HOST_OPTS="-h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} ${POSTGRES_EXTRA_OPTS}"

