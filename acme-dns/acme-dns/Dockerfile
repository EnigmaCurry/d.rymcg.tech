ARG IMAGE=joohoi/acme-dns:v1.0
FROM ${IMAGE}
RUN apk --no-cache add ca-certificates curl && update-ca-certificates
HEALTHCHECK --interval=30s --timeout=5s --start-period=0s --retries=1 \
  CMD curl -k -fsS --connect-timeout 1 --max-time 2 https://${API_HOST}:${API_PORT}/health || exit 1
