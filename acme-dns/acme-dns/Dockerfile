ARG IMAGE
FROM ${IMAGE}
RUN apk --no-cache add ca-certificates curl && update-ca-certificates
HEALTHCHECK --interval=30s --timeout=5s --start-period=0s --retries=1 \
  CMD curl -fsS --connect-timeout 1 --max-time 2 http://127.0.0.1:8080/health || exit 1
