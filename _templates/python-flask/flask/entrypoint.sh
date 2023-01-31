#!/bin/bash

echo "Starting server with public traefik host: https://${TRAEFIK_HOST}"
set -ex
gunicorn --worker-tmp-dir /dev/shm --workers=2 --threads=4 --worker-class=gthread --bind 0.0.0.0 api:app "$@"
