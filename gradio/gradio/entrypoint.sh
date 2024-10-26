#!/bin/bash

set -ex

case "${APP_MODE:-gradio}" in
  "proxy")
    gunicorn -w ${UVICORN_WORKERS} -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:7860 --preload main:app
    ;;
  "gradio")
    python main.py
    ;;
  *)
    echo "## No valid APP_MODE set, running your provided command directly."
    $@
    ;;
esac
