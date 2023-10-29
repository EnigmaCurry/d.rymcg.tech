#!/bin/bash

if [[ "${POSTGRES_MAINTAINANCE_MODE}" == "true" ]]; then
    exit 0
fi

pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
