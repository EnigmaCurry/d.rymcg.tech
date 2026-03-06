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

generate_authorization() {
    cat > ${AUTHZ} <<'HEADER'
authorization {
  default_permissions = {
    publish: { deny: ">" }
    subscribe: { deny: ">" }
  }
HEADER

    if [[ -n "${NATS_AUTH_USERS}" ]]; then
        echo "  users = [" >> ${AUTHZ}
        IFS=';' read -ra ENTRIES <<< "${NATS_AUTH_USERS}"
        for entry in "${ENTRIES[@]}"; do
            IFS=':' read -r cn pub sub <<< "${entry}"
            if [[ -z "${cn}" ]]; then
                continue
            fi
            echo "    {" >> ${AUTHZ}
            echo "      user: \"${cn}\"" >> ${AUTHZ}
            echo "      permissions: {" >> ${AUTHZ}

            # Publish permissions
            if [[ -z "${pub}" ]]; then
                echo "        publish: { deny: \">\" }" >> ${AUTHZ}
            else
                IFS=',' read -ra PUB_SUBJECTS <<< "${pub}"
                if [[ ${#PUB_SUBJECTS[@]} -eq 1 ]]; then
                    echo "        publish: \"${PUB_SUBJECTS[0]}\"" >> ${AUTHZ}
                else
                    printf -v pub_list '"%s", ' "${PUB_SUBJECTS[@]}"
                    echo "        publish: [${pub_list%, }]" >> ${AUTHZ}
                fi
            fi

            # Subscribe permissions
            if [[ -z "${sub}" ]]; then
                echo "        subscribe: { deny: \">\" }" >> ${AUTHZ}
            else
                IFS=',' read -ra SUB_SUBJECTS <<< "${sub}"
                if [[ ${#SUB_SUBJECTS[@]} -eq 1 ]]; then
                    echo "        subscribe: \"${SUB_SUBJECTS[0]}\"" >> ${AUTHZ}
                else
                    printf -v sub_list '"%s", ' "${SUB_SUBJECTS[@]}"
                    echo "        subscribe: [${sub_list%, }]" >> ${AUTHZ}
                fi
            fi

            echo "      }" >> ${AUTHZ}
            echo "    }" >> ${AUTHZ}
        done
        echo "  ]" >> ${AUTHZ}
    fi

    echo "}" >> ${AUTHZ}
}

if [[ "${NATS_JETSTREAM_ENABLE}" == "true" ]]; then
    cat >> ${CONFIG} <<'EOF'

jetstream {
  store_dir: /data/jetstream
}
EOF
    echo "[ ! ] JetStream ENABLED"
else
    echo "[ ! ] JetStream DISABLED"
fi

generate_authorization
echo "[ ! ] GENERATED AUTHORIZATION FILE ::: ${AUTHZ}"
if [[ -n "${NATS_AUTH_USERS}" ]]; then
    IFS=';' read -ra ENTRIES <<< "${NATS_AUTH_USERS}"
    for entry in "${ENTRIES[@]}"; do
        IFS=':' read -r cn pub sub <<< "${entry}"
        echo "[ ! ]   User: ${cn} publish=[${pub:-DENY}] subscribe=[${sub:-DENY}]"
    done
else
    echo "[ ! ]   No users configured. All access denied."
fi
