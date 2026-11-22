ARG IMAGE
FROM ${IMAGE}

RUN apk add -U bash su-exec
## The image grants the binary cap_net_bind_service as a file capability,
## which cannot be exec'd under no-new-privileges with cap_drop ALL. It
## listens on 8000, so it doesn't need it:
RUN setcap -r /bin/filebrowser
ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
