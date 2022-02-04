#!/bin/sh

source $(dirname ${BASH_SOURCE})/common.sh

echo "Making database dump of ${POSTGRES_DATABASE} ..."

SRC_FILE=dump.sql.gz
