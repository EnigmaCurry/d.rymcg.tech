# Add root TLS trust store for Step-CA (optional)
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

FROM golang:1.26-alpine AS builder
RUN mkdir -p /go/src/github.com/oauth2-proxy/oauth2-proxy
WORKDIR /go/src/github.com/oauth2-proxy/oauth2-proxy
RUN apk add --no-cache git make
ARG VERSION
ARG REPO=https://github.com/oauth2-proxy/oauth2-proxy.git
RUN git clone ${REPO} . && \
    git checkout ${VERSION}
ARG TARGETPLATFORM
ARG TARGETVARIANT
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      export GOARCH=arm64; \
    elif [ "$TARGETPLATFORM" = "linux/arm" ] && [ "$TARGETVARIANT" = "v7" ]; then \
      export GOARCH=arm GOARM=7; \
    elif [ "$TARGETPLATFORM" = "linux/arm" ] && [ "$TARGETVARIANT" = "v6" ]; then \
      export GOARCH=arm GOARM=6; \
    else \
      export GOARCH=amd64; \
    fi && \
    echo "Building for GOARCH=$GOARCH with variant $GOARM" && \
    CGO_ENABLED=0 GOOS=linux GOARCH=$GOARCH GOARM=$GOARM GO111MODULE=on \
      go build -a -installsuffix nocgo -o /oauth2-proxy .

# Copy into scratch container
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /oauth2-proxy ./
COPY --from=step_ca /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs
ENTRYPOINT ["./oauth2-proxy"]
