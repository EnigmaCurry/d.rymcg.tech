FROM debian:trixie AS build
ARG REDBEAN_VERSION
ARG REDBEAN_TARGET
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y git make zip unzip curl ca-certificates
WORKDIR /tmp/build
RUN git clone --depth 1 --branch ${REDBEAN_VERSION} https://github.com/jart/cosmopolitan
## build/bootstrap/make downloads the cosmocc toolchain the tree needs:
RUN cd cosmopolitan && \
    build/bootstrap/make -j$(nproc) o//tool/net/${REDBEAN_TARGET}

FROM build AS html-template
ARG REDBEAN_HTML_TEMPLATE
ARG REDBEAN_TARGET
ADD html-templates/${REDBEAN_HTML_TEMPLATE} /tmp/build/cosmopolitan/html-template
WORKDIR /tmp/build/cosmopolitan/html-template
RUN zip -r ../o//tool/net/${REDBEAN_TARGET} $(ls -A)

FROM debian:trixie-slim
ARG REDBEAN_UID=54321
ARG REDBEAN_GID=54321
ARG REDBEAN_TARGET
RUN groupadd -g ${REDBEAN_GID} redbean && \
    useradd -m redbean -s /usr/sbin/nologin -u ${REDBEAN_UID} -g redbean
COPY --from=html-template /tmp/build/cosmopolitan/o/tool/net/${REDBEAN_TARGET} /usr/local/bin/redbean
USER redbean
RUN mkdir ~/www
WORKDIR /home/redbean/www
EXPOSE 8080
CMD redbean -vv
