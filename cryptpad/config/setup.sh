#!/bin/bash
set -e

CONFIG_DIR=/cryptpad/config
TEMPLATE=/template/config.template.js
INFRA_TEMPLATE=/template/infra.template.js
CONFIG=${CONFIG_DIR}/config.js
INFRA=${CONFIG_DIR}/infra.js

for var in CPAD_MAIN_DOMAIN CPAD_SANDBOX_DOMAIN CRYPTPAD_ADMIN_EMAIL \
    CRYPTPAD_DEFAULT_STORAGE_LIMIT CRYPTPAD_MAX_UPLOAD_SIZE \
    CRYPTPAD_BLOCK_DAILY_CHECK CRYPTPAD_LOG_LEVEL; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: ${var} is empty."
        exit 1
    fi
done

echo "Creating new CryptPad config from template ..."
mkdir -p ${CONFIG_DIR}
cat ${TEMPLATE} | envsubst '${CPAD_MAIN_DOMAIN},${CPAD_SANDBOX_DOMAIN},${CRYPTPAD_ADMIN_EMAIL},${CRYPTPAD_DEFAULT_STORAGE_LIMIT},${CRYPTPAD_MAX_UPLOAD_SIZE},${CRYPTPAD_BLOCK_DAILY_CHECK},${CRYPTPAD_LOG_LEVEL}' > ${CONFIG}
echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"

## Since CryptPad 2026.10.0 the server also needs an 'infra' config
## (public endpoint + internal node topology) next to config.js. Render it
## here (as root) rather than letting the container's entrypoint create a
## default one: the config volume directory is root-owned, so the
## unprivileged entrypoint (uid 4001) could not write into it:
echo "Creating new CryptPad infra config from template ..."
cat ${INFRA_TEMPLATE} | envsubst '${CPAD_MAIN_DOMAIN},${CPAD_SANDBOX_DOMAIN}' > ${INFRA}
echo "[ ! ] GENERATED NEW INFRA CONFIG FILE ::: ${INFRA}"

## The cryptpad container runs as uid/gid 4001. The office (Euro-Office)
## volumes are mounted at paths which do not exist inside the image, so
## Docker creates them owned by root. Fix ownership of the top-level
## directories so the container can create files in them (install-office.sh
## runs as 4001):
chown 4001:4001 /onlyoffice-dist /onlyoffice-conf
echo "[ ! ] OFFICE VOLUME OWNERSHIP SET ::: 4001:4001"
