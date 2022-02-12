#!/bin/bash
CA_NAME=${CA_NAME:-local}
KEYSIZE=2048
VALID_DAYS=36525
CA_KEY=/CA/ca.key
CA_CERT=/CA/ca.pem
CERT_DIR=/cert

PRIVATE_KEY=${CERT_DIR}/key.pem
PUBLIC_KEY=${CERT_DIR}/public.pem
CSR=${CERT_DIR}/csr
CERT=${CERT_DIR}/cert.pem
CA_COPY=${CERT_DIR}/ca.pem
FULL_CHAIN=${CERT_DIR}/fullchain.pem

create_ca() {
    if [ ! -f ${CA_CERT} ]; then
        echo "Generating new Certificate Authority ... "
        ## Generate key:
        openssl genrsa -out ${CA_KEY} ${KEYSIZE}
        ## Generate self-signed CA cert:
        openssl req -new -x509 -key ${CA_KEY} -nodes -out ${CA_CERT} -subj "/CN=${CA_NAME}" -sha256 -days 36525 -verbose
    else
        echo "Existing CA found: ${CA_CERT}." && exit 0
    fi
}

get_ca() {
    cat ${CA_CERT}
}

create() {
    SAN=$1
    CHANGE_UID=${2:-1000}
    CHANGE_GID=${3:-1000}

    ## Generate key:
    (set -x; openssl genrsa -out ${PRIVATE_KEY} ${KEYSIZE})

    ## Export public key:
    (set -x; openssl rsa -in ${PRIVATE_KEY} -pubout -out ${PUBLIC_KEY})

    ## Generate request:
    (set -x; openssl req -new -key ${PRIVATE_KEY} -out ${CSR} -nodes -subj "/CN=${SAN}" -addext "subjectAltName = DNS:${SAN}" -verbose)

    ## Sign request:
    (set -x; openssl x509 -req -in ${CSR} -CA ${CA_CERT} -CAkey ${CA_KEY} -CAcreateserial -out ${CERT} -days ${VALID_DAYS})

    rm ${CSR}
    ## Create copy of CA cert
    cp ${CA_CERT} ${CA_COPY}
    ## Create full chain:
    cat ${CA_CERT} > ${FULL_CHAIN}    
    cat ${CA_COPY} >> ${FULL_CHAIN}
    (set -x; chown -R ${CHANGE_UID}:${CHANGE_GID} ${CERT_DIR})

    openssl x509 -in ${CERT} -noout -text

    echo "Private key: ${PRIVATE_KEY}"
    echo "Certificate: ${CERT}"
    echo "CA certificate: ${CA_COPY}"
    echo "Full chain: ${FULL_CHAIN}"
}

view() {
    openssl x509 -in ${CERT} -noout -text    
}

fingerprint() {
    openssl x509 -in ${CERT} -noout -subject
    openssl x509 -in ${CERT} -noout -issuer
    openssl x509 -in ${CERT} -noout -dates
    openssl x509 -in ${CERT} -noout -fingerprint
    openssl x509 -in ${CERT} -noout -fingerprint -sha256
}

download() {
    DOMAIN=$1; PORT=$2
    (set -x; openssl s_client -showcerts -servername ${DOMAIN} -connect ${DOMAIN}:${PORT} </dev/null 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p')
}

debug() {
    DOMAIN=$1; PORT=$2; TMP=$(mktemp)
    (set -x; openssl s_client -showcerts -servername ${DOMAIN} -connect ${DOMAIN}:${PORT} </dev/null 2>/dev/null \
         | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${TMP})
    (set -x; openssl x509 -in ${TMP} -noout -text)
    rm ${TMP}
}

$@
