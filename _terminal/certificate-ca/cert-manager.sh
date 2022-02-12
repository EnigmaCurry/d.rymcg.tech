#!/bin/bash

BIN=$(dirname ${BASH_SOURCE})/../../_scripts
source ${BIN}/funcs.sh

WORKDIR=$(dirname $(realpath $0))

help() {
    echo ""
    echo "cert-manager.sh - Create your own Certificate Authority in Docker."
    echo "USE THIS FOR TESTING PURPOSES ONLY. ALL CERTIFICATES ARE VALID FOR 100 YEARS."
    echo ""
    echo "./cert-manager.sh {CA_NAME} {COMMAND} [args ...]"
    echo ""
    echo "Commands: "
    echo "  cert-manager.sh CA_NAME create_ca                 ## creates the CA"
    echo "  cert-manager.sh CA_NAME get_ca                    ## Exports the CA certificate"
    echo "  cert-manager.sh CA_NAME create DOMAIN [UID] [GID] ## Create and sign new certificate for DOMAIN"
    echo "  cert-manager.sh CA_NAME get DOMAIN                ## Exports the full chain of certificates"
    echo "  cert-manager.sh CA_NAME delete DOMAIN             ## Deletes certificates for DOMAIN"
    echo "  cert-manager.sh CA_NAME list                      ## List all of the certificate volume names"
    echo ""
    echo "Create the CA (create_ca), then create (create) your domain certificates."
    echo "Mount the domain specific certificate volumes to your client containers."
    echo "If your containers do not run as UID/GID 1000, be sure to specify the "
    echo "correct values for create."
    echo ""
    echo "Examples:"
    echo " - Create the CA called root.example.com:  "
    echo ""
    echo "     ./cert-manager.sh root.example.com create_ca"
    echo ""
    echo " - Create certificate for www.example.com signed by the root CA: "
    echo ""
    echo "     ./cert-manager.sh root.example.com create www.example.com"
    echo ""
    echo ""
    echo "Example volumes directive to reference the certs in a docker-compose.yaml:"
    echo ""
    echo "volumes:"
    echo "  certs:"
    echo "    external: true"
    echo "    name: root.example.com_certificate-ca_\${WHATEVER_TRAEFIK_HOST}"
    echo ""
    echo "Example services directive to mount the certs volume:"
    echo ""
    echo "services:"
    echo "  whatever:"
    echo "    volumes:"
    echo "      - certs:/certs"
    echo ""
    echo "Certs will then be available in your container at /certs:"
    echo ""
    echo " /certs/cert.pem      - The public certificate (www.example.com)"
    echo " /certs/key.pem       - The private key (www.example.com)"
    echo " /certs/ca.pem        - The public CA cert (root.example.com)"
    echo " /certs/fullchain.pem - Both cert.pem and ca.pem in one file"
}

build() {
    cd ${WORKDIR}/ca
    (set -x; docker build -t localhost/${VOLUME_PREFIX} .)
}

create_ca() {
    build
    (set -x; docker run -e CA_NAME=${CA_NAME} --rm -v ${VOLUME_PREFIX}:/CA localhost/${VOLUME_PREFIX} create_ca) && \
        echo "CA established."
}

get_ca() {
    (set -x; docker run -e CA_NAME=${CA_NAME} --rm -v ${VOLUME_PREFIX}:/CA localhost/${VOLUME_PREFIX} get_ca)
}

create() {
    CERT_SAN=${DOMAIN:-$1}
    test -z ${CERT_SAN} && echo "DOMAIN (required) is not set. Exiting." && exit 1
    CERT_VOLUME=${VOLUME_PREFIX}_${CERT_SAN}
    CHANGE_UID=${2:-${CHANGE_UID}}
    CHANGE_UID=${CHANGE_UID:-1000}
    CHANGE_GID=${2:-${CHANGE_GID}}
    CHANGE_GID=${CHANGE_GID:-1000}

    ! docker image inspect localhost/${VOLUME_PREFIX} >/dev/null 2>&1 && echo "No CA docker image exists. Please run: cert-manager.sh build" && exit 1
    ! docker volume inspect ${VOLUME_PREFIX} >/dev/null 2>&1 && echo "No CA volume exists. Please run: cert-manager.sh create_ca" && exit 1

    if ! docker volume inspect ${CERT_VOLUME} > /dev/null 2>&1; then 
        (set -x; docker run  -e CA_NAME=${CA_NAME} --rm -v ${VOLUME_PREFIX}:/CA -v ${CERT_VOLUME}:/cert localhost/${VOLUME_PREFIX} create ${CERT_SAN} ${CHANGE_UID} ${CHANGE_GID})
        [ $? == 0 ] && \
            echo "Created new certificates volume '${CERT_VOLUME}'"
    else
        echo "Certificate volume already exists: ${CERT_VOLUME}"
    fi
}

get() {
    CERT_SAN=${DOMAIN:-$1}
    test -z ${CERT_SAN} && echo "DOMAIN (required) is not set. Exiting." && exit 1
    CERT_VOLUME=${VOLUME_PREFIX}_${CERT_SAN}
    if docker volume inspect ${CERT_VOLUME} > /dev/null 2>&1; then
        docker run -e CA_NAME=${CA_NAME} --rm -v ${CERT_VOLUME}:/cert debian:stable-slim cat /cert/fullchain.pem
    else
        echo "No certificate volume exists named '${CERT_VOLUME}'."
        exit 1
    fi
    
}

view() {
    CERT_SAN=${DOMAIN:-$1}
    test -z ${CERT_SAN} && echo "DOMAIN (required) is not set. Exiting." && exit 1
    CERT_VOLUME=${VOLUME_PREFIX}_${CERT_SAN}
    if docker volume inspect ${CERT_VOLUME} > /dev/null 2>&1; then
        docker run  -e CA_NAME=${CA_NAME} --rm -v ${VOLUME_PREFIX}:/CA -v ${CERT_VOLUME}:/cert localhost/${VOLUME_PREFIX} view ${CERT_SAN}
    else
        echo "No certificate volume exists named '${CERT_VOLUME}'."
        exit 1
    fi
}

fingerprint() {
    CERT_SAN=${DOMAIN:-$1}
    test -z ${CERT_SAN} && echo "DOMAIN (required) is not set. Exiting." && exit 1
    CERT_VOLUME=${VOLUME_PREFIX}_${CERT_SAN}
    if docker volume inspect ${CERT_VOLUME} > /dev/null 2>&1; then
        echo ""
        echo "### Verify TLS certificate fingerprints:"
        docker run  -e CA_NAME=${CA_NAME} --rm -v ${VOLUME_PREFIX}:/CA -v ${CERT_VOLUME}:/cert localhost/${VOLUME_PREFIX} fingerprint ${CERT_SAN}
    else
        echo "No certificate volume exists named '${CERT_VOLUME}'."
        exit 1
    fi
}


delete() {
    CERT_SAN=${DOMAIN:-$1}
    test -z ${CERT_SAN} && echo "DOMAIN (required) is not set. Exiting." && exit 1
    CERT_VOLUME=${VOLUME_PREFIX}_${CERT_SAN}
    if docker volume inspect ${CERT_VOLUME} > /dev/null 2>&1; then
        (set -x; docker volume rm ${CERT_VOLUME}) && echo "Deleted volume ${CERT_VOLUME}"
    else
        echo "No certificate volume exists named '${CERT_VOLUME}'."        
    fi
}

list() {
    echo "Volumes for CA: ${CA_NAME}"
    docker volume ls | grep ${VOLUME_PREFIX}
}

download() {
    [ "$#" -ne 1 ] && [ "$#" -ne 2 ] && \
        echo "download requires one or two args: the domain name and TCP port (default 443)" && \
        return 1
    DOMAIN=$1
    PORT=${2:-443}
    docker run -e CA_NAME=${CA_NAME} --rm -v ${VOLUME_PREFIX}:/CA localhost/${VOLUME_PREFIX} download ${DOMAIN} ${PORT}
}

debug() {
    [ "$#" -ne 1 ] && [ "$#" -ne 2 ] && \
        echo "debug requires one or two args: the domain name and TCP port (default 443)" && \
        return 1
    DOMAIN=$1
    PORT=${2:-443}
    docker run -e CA_NAME=${CA_NAME} --rm -v ${VOLUME_PREFIX}:/CA localhost/${VOLUME_PREFIX} debug ${DOMAIN} ${PORT}
}

main() {
    [[ $# == 0 ]] && help && exit 0
    [[ $# < 2 ]] && fault "Must specify CA_NAME and COMMAND."
    CA_NAME=${1}; shift
    [[ $(type -t $1) != function ]] && echo "Invalid command: $1" && exit 1
    VOLUME_PREFIX=${CA_NAME}_certificate-ca
    "$@"
}

main "$@"
