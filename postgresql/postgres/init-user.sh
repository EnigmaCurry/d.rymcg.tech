#!/bin/bash
set -e

## hook to create the POSTGRES_LIMITED_USER on fresh DB initialization.
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOF
     CREATE USER "${POSTGRES_LIMITED_USER}";
     CREATE EXTENSION pg_rational;
EOF
