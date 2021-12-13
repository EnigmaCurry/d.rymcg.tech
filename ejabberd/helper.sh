register() {
    IFS='@' read -ra JID <<< "$1"
    USERNAME=${JID[0]}
    VHOST=${JID[1]}
    [ ${#VHOST} == 0 ] && echo "Must enter full JID, eg. user@xmpp.example.com" && return
    PASSWORD=$(openssl rand -base64 32)
    echo "Creating user: ${USERNAME}@${VHOST}"
    echo "Password: ${PASSWORD}"
    docker exec ejabberd bin/ejabberdctl register ${USERNAME} ${VHOST} ${PASSWORD}
}

create_room() {
    ROOM=$1
    EJABBERD_HOST=$2
    CONF_HOST=conference.${EJABBERD_HOST}
    echo "Creating room ${ROOM}@${CONF_HOST}"
    docker exec ejabberd bin/ejabberdctl create_room ${ROOM} ${CONF_HOST} ${EJABBERD_HOST}
}

$*
