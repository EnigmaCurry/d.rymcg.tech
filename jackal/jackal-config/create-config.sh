#!/bin/bash
TEMPLATE=/template/config.template.yaml
CONFIG=/config/config.yaml
GENERATE=false

[[ ! -f ${CONFIG} ]] && \
    echo "No config file found." && GENERATE=true
[[ $FORCE_CREATE_CONFIG == true ]] && \
    echo "Force creating new config file ..." && GENERATE=true

if [[ $GENERATE == true ]]; then
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
else
    echo "[ * ] Using existing config file from volume: ${CONFIG}"
fi
[[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
sleep 5
