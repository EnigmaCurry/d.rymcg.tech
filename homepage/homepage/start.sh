#!/bin/sh
# Invoke this from the docker ENTRYPOINT to start the webhook reloader
# and to start the main service
node /app/reloader/webhook_reloader.js &
node /app/server.js
