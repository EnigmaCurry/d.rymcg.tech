#!/bin/bash

ROOT_CA_NAME="${ROOT_CA_NAME:-Example CA}"
# 100 year expiration by default:
EXPIRATION="${EXPIRATION:-876000h}"

## Create the root Certificate Authority:
step certificate create --insecure --no-password --profile root-ca "${ROOT_CA_NAME}" root_ca.crt root_ca.key

## Create the server certificate:
step certificate create --insecure --no-password --profile leaf server server.crt server.key --not-after="${EXPIRATION}" --ca root_ca.crt --ca-key root_ca.key

## Create the client certificate:
step certificate create --insecure --no-password --profile leaf client client.crt client.key --not-after="${EXPIRATION}" --ca root_ca.crt --ca-key root_ca.key

## Chown the certitifcates to the postgres user:
chown 999:999 -R /certs

