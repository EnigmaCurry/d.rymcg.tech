FROM alpine:latest as redbean-builder
ARG REDBEAN_VERSION
ARG CALCPAD_VERSION
RUN apk add --update zip npm python3 make g++
RUN wget https://redbean.dev/redbean-original-${REDBEAN_VERSION}.com \
    -O redbean.com
RUN chmod +x redbean.com && \
    ls -la redbean.com && \
    zip -sf redbean.com && \
    sh /redbean.com --assimilate

FROM redbean-builder as calcpad-builder
ADD https://github.com/EnigmaCurry/CalcPad/archive/${CALCPAD_VERSION}.tar.gz calcpad.tar.gz
RUN tar xfv calcpad.tar.gz && \
    cd CalcPad-${CALCPAD_VERSION} && \
    npm install && \
    npm run build-web && \
    cd docs && \
    (test -f index.html || mv index-web.html index.html) && \
    zip -r /redbean.com $(ls -A)

FROM scratch as redbean-calcpad-server
ARG CALCPAD_UID=54321
ARG CALCPAD_GID=54321
COPY --from=calcpad-builder /redbean.com /
USER ${CALCPAD_UID}:${CALCPAD_GID}
EXPOSE 8080
CMD ["/redbean.com", "-vv"]
