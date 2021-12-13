#!/bin/bash

CA_NAME=local-certificate-ca
WORKDIR=$(dirname $(realpath $0))
VOLUME_PREFIX=${CA_NAME}_

help() {
    echo ""
    echo "cert-manager.sh - Create your own Certificate Authority in Docker"
    echo "USE THIS FOR TESTING PURPOSES ONLY. ALL CERTIFICATES ARE VALID FOR 100 YEARS."
    echo ""
    echo "Commands: "
    echo "  cert-manager.sh build  ## builds the docker image (run this one time)"
    echo "  cert-manager.sh create_ca  ## creates the CA"
    echo "  cert-manager.sh get_ca  ## Exports the CA certificate"
    echo "  cert-manager.sh create DOMAIN [UID GID] ## Creates new certificate for DOMAIN"
    echo "  cert-manager.sh get DOMAIN ## Exports the full chain of certificates"
    echo "  cert-manager.sh delete DOMAIN ## Deletes certificates for DOMAIN"
    echo "  cert-manager.sh list ## List all of the certificate volume names"
    echo ""
    echo "Build the image, create the CA, then create your domain certificates."
    echo "Mount the domain specific certificate volumes to your client containers."
    echo "If your containers do not run as UID/GID 1000, be sure to specify the "
    echo "correct values for create."
    echo ""
}

build() {
    set -x
    cd ${WORKDIR}/ca
    docker build -t ${CA_NAME} .
}

create_ca() {
    (set -x; docker run --rm -v ${CA_NAME}:/CA ${CA_NAME} create_ca) && \
        echo "CA created. To view the certificate, run: cert-manager.sh get_ca"
}

get_ca() {
    set -x
    docker run --rm -v ${CA_NAME}:/CA ${CA_NAME} get_ca
}

create() {
    [ "$#" -ne 1 ] && [ "$#" -ne 3 ] && \
        echo "create requires one or three args: the DOMAIN name [and the UID and GID]" && \
        return 1
    CERT_SAN=$1
    CERT_VOLUME=${VOLUME_PREFIX}${CERT_SAN}
    CHANGE_UID=${2:-1000}
    CHANGE_GID=${3:-1000}

    ! docker image inspect ${CA_NAME} >/dev/null 2>&1 && echo "No CA docker image exists. Please run: cert-manager.sh build" && exit 1
    ! docker volume inspect ${CA_NAME} >/dev/null 2>&1 && echo "No CA volume exists. Please run: cert-manager.sh create_ca" && exit 1

    if ! docker volume inspect ${CERT_VOLUME} > /dev/null 2>&1; then 
        (set -x; docker run --rm -v ${CA_NAME}:/CA -v ${CERT_VOLUME}:/cert ${CA_NAME} create ${CERT_SAN} ${CHANGE_UID} ${CHANGE_GID})
        [ $? == 0 ] && \
            echo "Created new certificates volume '${CERT_VOLUME}'" && \
            echo "To view this certificate chain, run: cert-manager.sh get ${CERT_SAN}" && \
            echo "Or mount the volume '${CERT_VOLUME}' to your client container"

    else
        echo "Certificate volume already exists: ${CERT_VOLUME}"
        echo "If you wish to regenerate this certificate, you must destroy this volume, and try again."
        exit 1
    fi
}

get() {
    [ "$#" -ne 1 ] && \
        echo "get requires one arg: the domain name (or SAN [or CN])" && \
        return 1
    CERT_SAN=$1
    CERT_VOLUME=${VOLUME_PREFIX}${CERT_SAN}
    if docker volume inspect ${CERT_VOLUME} > /dev/null 2>&1; then
        docker run --rm -v ${CERT_VOLUME}:/cert debian:stable-slim cat /cert/fullchain.pem
    else
        echo "No certificate volume exists named '${CERT_VOLUME}'."
        echo "To create certificates, run: cert-manager.sh create ${CERT_SAN}"
        exit 1
    fi
    
}

delete() {
    [ "$#" -ne 1 ] && \
        echo "delete requires one arg: the domain name (or SAN [or CN])" && \
        return 1
    CERT_SAN=$1
    CERT_VOLUME=${VOLUME_PREFIX}${CERT_SAN}
    if docker volume inspect ${CERT_VOLUME} > /dev/null 2>&1; then
        (set -x; docker volume rm ${CERT_VOLUME} && echo "Deleted volume ${CERT_VOLUME}")
    else
        echo "No certificate volume exists named '${CERT_VOLUME}'."        
    fi
}

list() {
    echo "Volumes for CA: ${CA_NAME}"
    docker volume ls | grep ${CA_NAME}
}

[[ $# == 0 ]] && help && exit 0
[[ $(type -t $1) != function ]] && echo "Invalid command: $1" && exit 1

$*
