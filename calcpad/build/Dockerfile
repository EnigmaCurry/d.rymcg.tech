ARG SWS_VERSION
FROM alpine:3.22 AS calcpad-builder
ARG CALCPAD_VERSION
RUN apk add --update npm python3 make g++
ADD https://github.com/EnigmaCurry/CalcPad/archive/${CALCPAD_VERSION}.tar.gz calcpad.tar.gz
RUN tar xf calcpad.tar.gz && \
    cd CalcPad-${CALCPAD_VERSION} && \
    npm install && \
    npm run build-web && \
    cd docs && \
    (test -f index.html || mv index-web.html index.html) && \
    mv /CalcPad-${CALCPAD_VERSION}/docs /public

FROM ghcr.io/static-web-server/static-web-server:${SWS_VERSION}
ARG CALCPAD_UID=54321
ARG CALCPAD_GID=54321
COPY --from=calcpad-builder /public /public
ENV SERVER_PORT=8080 \
    SERVER_ROOT=/public \
    SERVER_LOG_LEVEL=info
USER ${CALCPAD_UID}:${CALCPAD_GID}
