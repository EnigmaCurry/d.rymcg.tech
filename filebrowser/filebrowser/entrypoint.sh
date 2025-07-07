#!/bin/sh

set -euo pipefail

CONFIG=/.filebrowser.json
DATABASE=/database/filebrowser.db
ROOT_DIR=/srv

stderr(){ echo "$@" >/dev/stderr; }
error(){ stderr "Error: $@"; }
fault(){ test -n "$1" && error $1; stderr "Exiting."; exit 1; }
check_var(){
    local __missing=false
    local __vars="$@"
    for __var in ${__vars}; do
        if [[ -z "${!__var}" ]]; then
            error "${__var} variable is missing."
            __missing=true
        fi
    done
    if [[ ${__missing} == true ]]; then
        fault
    fi
}

rm -f /usr/local/bin/filebrowser
ln -s /filebrowser /usr/local/bin/filebrowser
mkdir -p ${ROOT_DIR}

# check_var AUTH_TYPE ADMIN_USERNAME ADMIN_PASSWORD

############################################################
## Create config
############################################################
cat > ${CONFIG} <<EOF
{
  "port": 8000,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "$DATABASE",
  "root": "$ROOT_DIR"
}
EOF

############################################################
## Initialize database and accounts
############################################################
if [[ ! -f "$DATABASE" ]]; then
    filebrowser config init
    filebrowser users add "${ADMIN_USERNAME}" "${ADMIN_PASSWORD}" --perm.admin
else
    (set -x; chown ${FILEBROWSER_UID}:${FILEBROWSER_GID} ${DATABASE}; stat $DATABASE)
fi

if [[ "$AUTH_TYPE" == "json" ]]; then
    echo "## Setting default json auth"
    filebrowser config set --auth.method=json
    filebrowser users update 1 --username "$ADMIN_USERNAME" --password "$ADMIN_PASSWORD"
elif [[ "$AUTH_TYPE" == "proxy" ]]; then
    echo "## Setting proxy sentry auth"
    filebrowser config set --auth.method=proxy --auth.header=X-Forwarded-User
    filebrowser users update 1 --username "$ADMIN_USERNAME"
else
    echo "Invalid AUTH_TYPE: ${AUTH_TYPE}"
    exit 1
fi
filebrowser users ls


############################################################
## Startup
############################################################
echo "Dropping privileges before starting filebrowser (UID $FILEBROWSER_UID)"
exec su-exec "$FILEBROWSER_UID" "/filebrowser" $@
