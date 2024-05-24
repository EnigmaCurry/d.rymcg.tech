FROM alpine:3
RUN apk add -U curl step-cli bash
RUN if [[ $(arch) == "x86_64" ]]; then \
        curl https://dl.min.io/client/mc/release/linux-amd64/mc \
            -o /usr/local/bin/mc; \
    elif [[ $(arch) == "aarch64" ]]; then \
        curl https://dl.min.io/client/mc/release/linux-arm64/mc \
            -o /usr/local/bin/mc; \
    fi; \
    chmod a+x /usr/local/bin/mc
ARG STEP_CA_ENABLED STEP_CA_ENDPOINT STEP_CA_FINGERPRINT
RUN if [[ "${STEP_CA_ENABLED}" == "true" ]]; then \
    step ca bootstrap --ca-url "${STEP_CA_ENDPOINT}" \
    --fingerprint "${STEP_CA_FINGERPRINT}" \
    --install --force; \
    fi; \
