#!/bin/bash

error(){ echo "Error: $@" >/dev/stderr; }
fault(){ test -n "$1" && error $1; echo "Exiting." >/dev/stderr; exit 1; }
exe() { (set -x; "$@"); }
check_var(){
    local __missing=false
    local __vars="$@"
    for __var in ${__vars}; do
        if [[ -z "${!__var}" ]]; then
            error "${__var} variable is missing."
            __missing=true
        fi
    done
    if [[ ${__missing} == true ]]; then
        fault
    fi
}

SRC=$(dirname "${BASH_SOURCE}")
UNITS_DIR=${HOME}/.config/containers/systemd

check_var PODMAN_WORKSTATION_IMAGE PODMAN_WORKSTATION_INSTANCE PODMAN_SSH_IP_ADDRESS PODMAN_SSH_PORT

mkdir -p ${UNITS_DIR}

echo "# Writing systemd unit files to ${UNITS_DIR}"
cat ${SRC}/podman_workstation.container.template | envsubst > "${UNITS_DIR}/${PODMAN_WORKSTATION_IMAGE}-${PODMAN_WORKSTATION_INSTANCE}.container"
echo "# Reloading systemd units"
systemctl --user daemon-reload
systemctl --user list-unit-files | grep "^${PODMAN_WORKSTATION_IMAGE}-${PODMAN_WORKSTATION_INSTANCE}.service .*"
if [[ "${PODMAN_WORKSTATION_SYSTEMD_WANTED_BY}" == "default.target" ]]; then
    echo "# Starting service"
    systemctl --user restart "${PODMAN_WORKSTATION_IMAGE}-${PODMAN_WORKSTATION_INSTANCE}.service"
    systemctl --user status --no-pager "${PODMAN_WORKSTATION_IMAGE}-${PODMAN_WORKSTATION_INSTANCE}.service"
    echo "Service scheduled to automatically start on system boot."
fi
