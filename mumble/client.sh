#!/bin/bash

set -e
BIN=../_scripts
source ${BIN}/funcs.sh

ACCOUNT=$1;
check_var ACCOUNT

## Create a new config and database directories:
NEW_CONFIG="${HOME}/.config/Mumble/${ACCOUNT}"
NEW_DATA="${HOME}/.local/share/Mumble/${ACCOUNT}"
mkdir -p "${NEW_CONFIG}"
mkdir -p "${NEW_DATA}"

if [[ ! -f "${NEW_CONFIG}/mumble_settings.json" ]]; then
    ## Create a new config with the correct new database location:
    echo "{}" | jq ".misc.database_location = \"${NEW_DATA}/mumble.sqlite\"" \
        | jq ".settings_version = 1" \
        | jq ".ui.theme_style = \"Dark\"" \
        | jq ".mumble_has_quit_normally = true" \
        | jq ".misc.audio_wizard_has_been_shown = true" \
        | jq ".misc.viewed_server_ping_consent_message = true" \
        | jq ".ui.disable_public_server_list = true" \
             > "${NEW_CONFIG}/mumble_settings.json"
fi

touch "${NEW_DATA}/mumble.sqlite"

cat "${NEW_CONFIG}/mumble_settings.json" | jq ".certificate" | md5sum

## Launch mumble client using the new config:
mumble -c "${NEW_CONFIG}/mumble_settings.json"

cat "${NEW_CONFIG}/mumble_settings.json" | jq ".certificate"  | md5sum
