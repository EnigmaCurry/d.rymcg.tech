# This Dockerfile just changes the root TLS trust store for Step-CA (optional)
# It uses the base image you set as TRAEFIK_FORWARD_AUTH_BASE_IMAGE
ARG BASE_IMAGE

## Build Step-CA certificate store:
FROM alpine:3 AS step_ca
ARG STEP_CA_ENABLED STEP_CA_ENDPOINT STEP_CA_FINGERPRINT STEP_CA_ZERO_CERTS
RUN apk add -U step-cli ca-certificates
RUN ([[ "$STEP_CA_ENABLED" == "true" ]] && \
    step ca bootstrap --ca-url "${STEP_CA_ENDPOINT}" --fingerprint "${STEP_CA_FINGERPRINT}")  || true
RUN ([[ "$STEP_CA_ENABLED" == "true" ]] && [[ "$STEP_CA_ZERO_CERTS" == "true" ]] && \
    cat /root/.step/certs/root_ca.crt > /etc/ssl/certs/ca-certificates.crt) || true
RUN ([[ "$STEP_CA_ENABLED" == "true" ]] && [[ "$STEP_CA_ZERO_CERTS" != "true" ]] && \
    cat /root/.step/certs/root_ca.crt >> /etc/ssl/certs/ca-certificates.crt) || true

## Copy Step-CA certificate store into the otherwise unmodified base image:
FROM ${BASE_IMAGE:-thomseddon/traefik-forward-auth:2}
COPY --from=step_ca /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs
