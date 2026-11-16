#!/bin/bash
## admin_user.sh - manage Forgejo accounts from the command line (the web
## install wizard is locked, see FORGEJO__security__INSTALL_LOCK).
##
## Usage (run from the Makefile, which sets ENV_FILE and ROOT_DIR):
##   admin_user.sh ensure-root      # create FORGEJO_ADMIN_USER if no admin exists
##   admin_user.sh create USER      # create another admin account
##   admin_user.sh reset USER       # set a new random password for USER
##
## New passwords are generated randomly and printed once; they are not saved.

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh
set -eo pipefail

forgejo_cli() {
    ## Run the forgejo CLI in the running container (no TTY needed):
    make --no-print-directory docker-compose-lifecycle-cmd QUIET=true \
         EXTRA_ARGS="exec -T forgejo forgejo $*"
}

new_password() {
    openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 24
}

print_password() {
    local user="$1" password="$2"
    echo
    echo "## Forgejo account ready:"
    echo "##   URL:      $(${BIN}/dotenv -f ${ENV_FILE} get FORGEJO__server__ROOT_URL)"
    echo "##   Username: ${user}"
    echo "##   Password: ${password}"
    echo "## Save this password now; it is not stored anywhere."
    echo "## (Reset it later with: make admin-password)"
    echo
}

create_admin() {
    local user="$1" email password
    email="${user}@$(${BIN}/dotenv -f ${ENV_FILE} get FORGEJO_TRAEFIK_HOST)"
    password=$(new_password)
    forgejo_cli admin user create --admin --username "${user}" --email "${email}" \
                --password "${password}" --must-change-password=false >/dev/null
    print_password "${user}" "${password}"
}

wait_for_cli() {
    ## The container can be "up" before the database is migrated:
    local i
    for i in $(seq 1 30); do
        forgejo_cli admin user list >/dev/null 2>&1 && return 0
        sleep 2
    done
    fault "Forgejo CLI is not responding (is the container running?)"
}

case "$1" in
    ensure-root)
        wait_for_cli
        ## The listing has a header row; any further row is an admin:
        if [[ $(forgejo_cli admin user list --admin | wc -l) -gt 1 ]]; then
            echo "Forgejo already has an admin account."
        else
            create_admin "$(${BIN}/dotenv -f ${ENV_FILE} get FORGEJO_ADMIN_USER)"
        fi
        ;;
    create)
        [[ -n "$2" ]] || fault "Usage: admin_user.sh create USERNAME"
        wait_for_cli
        create_admin "$2"
        ;;
    reset)
        [[ -n "$2" ]] || fault "Usage: admin_user.sh reset USERNAME"
        wait_for_cli
        password=$(new_password)
        forgejo_cli admin user change-password --username "$2" \
                    --password "${password}" --must-change-password=false >/dev/null
        print_password "$2" "${password}"
        ;;
    *)
        fault "Usage: admin_user.sh ensure-root|create USER|reset USER"
        ;;
esac
