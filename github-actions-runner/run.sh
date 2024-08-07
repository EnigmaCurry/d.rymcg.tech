#!/bin/sh

set -e

PATH=${HOME}/.cargo/bin:${PATH}
export CROSS_CONTAINER_IN_CONTAINER=true
docker context create --docker "host=tcp://docker:2376,ca=/certs/client/ca.pem,cert=/certs/client/cert.pem,key=/certs/client/key.pem" docker || true
docker context use docker

test -f .credentials || /actions-runner/config.sh  --unattended --url ${REPOSITORY} --token ${RUNNER_TOKEN}
/actions-runner/run.sh
