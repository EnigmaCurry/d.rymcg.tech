source ../_scripts/funcs.sh

register() {
    check_var ENV_FILE USERNAME EJABBERD_HOST
    PASSWORD=$(openssl rand -base64 32)
    echo "Creating user: ${USERNAME}@${VHOST}"
    echo "Password: ${PASSWORD}"
    docker compose --env-file ${ENV_FILE} exec ejabberd bin/ejabberdctl register ${USERNAME} ${EJABBERD_HOST} ${PASSWORD}
}

create_room() {
    check_var ENV_FILE ROOM EJABBERD_HOST
    CONF_HOST=conference.${EJABBERD_HOST}
    echo "Creating room ${ROOM}@${CONF_HOST}"
    docker compose --env-file ${ENV_FILE} exec ejabberd bin/ejabberdctl create_room ${ROOM} ${CONF_HOST} ${EJABBERD_HOST}
}

$*
