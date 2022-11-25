#!/bin/bash

TMP_DIR=$(mktemp -d)
echo "## TMP_DIR=${TMP_DIR}"
trap cleanup SIGINT SIGTERM SIGQUIT SIGABRT ERR EXIT

cleanup() {
    set -ex
    rm -rf ${TMP_DIR}
}

set -e

