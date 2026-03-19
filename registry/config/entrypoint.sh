#!/bin/sh
set -eu

log() { printf '%s %s\n' "[config]" "$*"; }
die() { printf '%s %s\n' "[config][ERROR]" "$*" >&2; exit 1; }

CFG_DIR=/etc/docker/registry
CFG_PATH=${CFG_DIR}/config.yml

[ -d "$CFG_DIR" ] || mkdir -p "$CFG_DIR" || die "cannot mkdir $CFG_DIR"
chmod 0755 "$CFG_DIR" 2>/dev/null || true
[ -w "$CFG_DIR" ] || die "config dir not writable: $CFG_DIR (is the volume mounted?)"

STORAGE_BACKEND=${REGISTRY_STORAGE_BACKEND:-docker}

if [ "$STORAGE_BACKEND" = "docker" ]; then
    log "storage backend: docker volume (filesystem)"
    STORAGE_SECTION="  filesystem:
    rootdirectory: /var/lib/registry"
elif [ "$STORAGE_BACKEND" = "s3" ]; then
    [ -n "${REGISTRY_STORAGE_S3_BUCKET:-}" ] || die "REGISTRY_STORAGE_S3_BUCKET is required for S3 storage"
    [ -n "${REGISTRY_STORAGE_S3_ACCESSKEY:-}" ] || die "REGISTRY_STORAGE_S3_ACCESSKEY is required for S3 storage"
    [ -n "${REGISTRY_STORAGE_S3_SECRETKEY:-}" ] || die "REGISTRY_STORAGE_S3_SECRETKEY is required for S3 storage"
    log "storage backend: s3 (bucket: ${REGISTRY_STORAGE_S3_BUCKET})"
    STORAGE_SECTION="  s3:
    regionendpoint: ${REGISTRY_STORAGE_S3_REGIONENDPOINT:-}
    region: ${REGISTRY_STORAGE_S3_REGION:-us-east-1}
    bucket: ${REGISTRY_STORAGE_S3_BUCKET}
    accesskey: ${REGISTRY_STORAGE_S3_ACCESSKEY}
    secretkey: ${REGISTRY_STORAGE_S3_SECRETKEY}
    secure: true
    v4auth: true
    chunksize: 33554432"
else
    die "unknown storage backend: $STORAGE_BACKEND"
fi

TMP=$(mktemp)
cat > "$TMP" <<EOF
version: 0.1
log:
  fields:
    service: registry
storage:
${STORAGE_SECTION}
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF

if [ -f "$CFG_PATH" ]; then
    rm "$CFG_PATH" || chmod 0644 "$CFG_PATH"
fi
mv "$TMP" "$CFG_PATH"
chmod 0444 "$CFG_PATH"
log "wrote $CFG_PATH"
