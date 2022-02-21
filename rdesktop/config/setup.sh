#!/bin/bash

template_files() {
    ## Render templates recursively, substituting environment variables:
    TEMPLATE_DIR=${1}
    CONFIG_DIR=${2}
    shopt -s globstar
    shopt -s dotglob
    set -e
    for file in ${TEMPLATE_DIR}/**/*; do
        if [[ -f ${file} ]]; then
            file=$(echo "${file}" | sed "s|^${TEMPLATE_DIR}/||")
            mkdir -p ${CONFIG_DIR}/$(dirname ${file})
            cat ${TEMPLATE_DIR}/${file} | envsubst > ${CONFIG_DIR}/${file}
            echo "[ ! ] RENDERED FILE FROM TEMPLATE ::: ${CONFIG_DIR}/${file}"
        fi
    done
    shopt -u dotglob
    shopt -u globstar
}

template_files /template/files /config

chmod a+x /config/startwm.sh

