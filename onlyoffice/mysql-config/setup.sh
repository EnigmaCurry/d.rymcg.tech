#!/bin/bash
set -e
set -x # debug

gettext_template() {
    src=$1; dst=$2;
    dst_path=$(dirname "$2")
    
    mkdir -p ${dst_path}
    rm -rf ${dst_path}/*

    [ -e "${src}" ] || (echo "Template not found: ${src}" && exit 1)
    envsubst < ${src} > ${dst}
    success=$?
    echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${dst}"
    return ${success}
}

create_config() {
    # Currently there are no env vars to template in `onlyoffice.cnf` but we need to copy the file anyway so I'm letting envsubst do it. Maybe in the future we'll variablize some of it.
    gettext_template onlyoffice.cnf /etc/mysql/conf.d/onlyoffice.cnf
    cat /etc/mysql/conf.d/onlyoffice.cnf # debug

    gettext_template setup.sql /docker-entrypoint-initdb.d/setup.sql
    cat /docker-entrypoint-initdb.d/setup.sql # debug
}

create_config
