#!/bin/bash

CA_JSON=/home/step/config/ca.json

array_to_json() {
    # array_to_json "${THINGS[@]}"
    printf '%s\n' "$@" | jq -R . | jq -c -s .
}

config_set() {
    (
        set -e
        tmp=$(mktemp)
        KEY="${1}"
        ARG="${2}"
        jq "${KEY} = \"${ARG}\"" ${CA_JSON} > "$tmp"
        mv "$tmp" ${CA_JSON}
        echo "Set ${KEY} = ${ARG}"
    )
}

config_set_array() {
    (
        set -e
        tmp=$(mktemp)
        KEY="${1}"
        ARG="${2}"
        IFS=', ' read -r -a arr <<< "${ARG}"
        ARG=$(array_to_json "${arr[@]}")
        jq "${KEY} = ${ARG}" ${CA_JSON} > "$tmp"
        mv "$tmp" ${CA_JSON}
        echo "Set ${KEY} = ${ARG}"
    )
}


edit_config() {
    if [[ -f ${CA_JSON} ]]; then
        echo
        config_set .authority.claims.minTLSCertDuration "${AUTHORITY_CLAIMS_MIN_TLS_CERT_DURATION}"
        config_set .authority.claims.maxTLSCertDuration "${AUTHORITY_CLAIMS_MAX_TLS_CERT_DURATION}"
        config_set .authority.claims.defaultTLSCertDuration "${AUTHORITY_CLAIMS_DEFAULT_TLS_CERT_DURATION}"
        config_set_array .authority.policy.x509.allow.dns "${AUTHORITY_POLICY_X509_ALLOW_DNS}"
    else
        echo "ERROR: Missing ${CA_JSON} - This is normal if you're starting fresh."
        echo "IMPORTANT: Let the container startup and it will create /home/step/config/ca.json automatically."
        echo "IMPORTANT: After that's done, you must run \`make restart\` to let this script run again."
        exit 1
    fi
}

echo "## $(date)"
edit_config
