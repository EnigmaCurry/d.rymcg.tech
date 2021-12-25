#!/bin/bash

DEV_CONSOLE=${DEV_CONSOLE:-false}

if [[ ${DEV_CONSOLE} == true ]]; then
    ARGS="--devconsole"
else
    ARGS=""
fi

websocketd ${ARGS} --port=8080 app
