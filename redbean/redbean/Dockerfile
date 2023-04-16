FROM debian:bullseye as build
ARG REDBEAN_VERSION
ARG REDBEAN_TARGET
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y git build-essential zip
WORKDIR /tmp/build
RUN git clone https://github.com/jart/cosmopolitan && \
    cd cosmopolitan && \
    git checkout ${REDBEAN_VERSION} && \
    make -j8 o//tool/net/${REDBEAN_TARGET}

FROM build as html-template
ARG REDBEAN_HTML_TEMPLATE
ARG REDBEAN_TARGET
ADD html-templates/${REDBEAN_HTML_TEMPLATE} /tmp/build/cosmopolitan/html-template
WORKDIR /tmp/build/cosmopolitan/html-template
RUN zip -r ../o//tool/net/${REDBEAN_TARGET} $(ls -A)

FROM debian:bullseye-slim
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
