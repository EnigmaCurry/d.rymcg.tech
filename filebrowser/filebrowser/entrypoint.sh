#!/bin/sh

CONFIG=/.filebrowser.json
DATABASE=/database/filebrowser.db

rm -f /usr/local/bin/filebrowser
ln -s /filebrowser /usr/local/bin/filebrowser
cp /config/config.json "$CONFIG"

case "$AUTH_TYPE" in
  proxy|json)
    # Valid AUTH_TYPE
    ;;
  *)
    echo "Invalid AUTH_TYPE: $AUTH_TYPE"
    exit 1
    ;;
esac

if [[ -z "$ADMIN_USERNAME" ]]; then
    echo "Missing ADMIN_USERNAME"
    exit 1
fi
if [[ -z "$ADMIN_PASSWORD" ]]; then
    echo "Missing ADMIN_PASSWORD"
    exit 1
fi

if [[ ! -f "$DATABASE" ]]; then
    filebrowser config init
    filebrowser users add "${ADMIN_USERNAME}" "${ADMIN_PASSWORD}" --perm.admin
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

echo "## Starting filebrowser"
filebrowser
