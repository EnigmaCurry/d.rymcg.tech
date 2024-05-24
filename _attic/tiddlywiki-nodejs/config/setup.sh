#!/bin/bash
set -e

TEMPLATE=/template/tiddlywiki.info.yaml
CONFIG_FILE=/tiddlywiki/tiddlywiki.info

ytt_template() {
    src=$1; dst=$2;
    echo TIDDLYWIKI_NODEJS_PLUGINS=${TIDDLYWIKI_NODEJS_PLUGINS}
    [ -e "${src}" ] || (echo "Template not found: ${src}" && exit 1)
    ytt -o json -f ${src} \
        -v "plugins=${TIDDLYWIKI_NODEJS_PLUGINS}" \
        | jq "." > ${dst}
    success=$?
    echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${dst}"
    cat ${dst}
    return ${success}
}

create_config() {
    ytt_template ${TEMPLATE} ${CONFIG_FILE}
    test -z "$(cat  ${CONFIG_FILE})" && echo "# ERROR: config file is empty: ${CONFIG_FILE}" && exit 1
}

create_config
