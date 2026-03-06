#!/bin/bash

CONFIG_DIR=/etc/nats
CONFIG=${CONFIG_DIR}/nats.conf
AUTHZ=${CONFIG_DIR}/authorization.conf

if [[ -z "${NATS_CLUSTER_NAME}" ]]; then
    echo "NATS_CLUSTER_NAME is empty."
    exit 1
fi

if [[ -z "${NATS_TRAEFIK_HOST}" ]]; then
    echo "NATS_TRAEFIK_HOST is empty."
    exit 1
fi

echo "Creating new NATS config from template ..."
mkdir -p ${CONFIG_DIR}
cat /template/nats.conf | envsubst '${NATS_CLUSTER_NAME},${NATS_TRAEFIK_HOST}' > ${CONFIG}
echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"

if [[ "${NATS_AUTHORIZATION_ENABLE}" == "true" ]]; then
    AUTHZ_TEMPLATE=/template/context/${NATS_DOCKER_CONTEXT}/authorization.conf
    if [[ -f ${AUTHZ_TEMPLATE} ]]; then
        cat ${AUTHZ_TEMPLATE} | envsubst > ${AUTHZ}
        echo "[ ! ] GENERATED AUTHORIZATION FILE from context template ::: ${AUTHZ}"
    else
        echo "[ ! ] WARNING: No context authorization file exists at ${AUTHZ_TEMPLATE}."
        echo "[ ! ] Denying all access. Create config/template/context/${NATS_DOCKER_CONTEXT}/authorization.conf"
        echo "[ ! ] See authorization.example.conf for the format."
        cat > ${AUTHZ} <<'EOF'
authorization {
  default_permissions = {
    publish: { deny: ">" }
    subscribe: { deny: ">" }
  }
}
EOF
    fi
else
    cat /dev/null > ${AUTHZ}
    echo "[ ! ] Authorization disabled. All authenticated users have full access."
fi
