#!/bin/bash

set -e

test -z "${VMNAME}" && echo "Must set VMNAME environment variable"

# Remove Host entry from ssh config:
# (Thanks Ryan https://stackoverflow.com/a/36121613)
TMP=$(mktemp)
sed < ~/.ssh/config "/^$/d;s/Host /$NL&/" | sed '/^Host '"${VMNAME}"'$/,/^$/d;' > ${TMP}
cat ${TMP} > ~/.ssh/config
rm -f ${TMP}

docker context rm ${VMNAME} || true
