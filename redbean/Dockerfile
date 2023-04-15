FROM debian:bullseye as build
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install git build-essential

FROM debian:bullseye-slim
ARG REDBEAN_UID=54321
ARG REDBEAN_GID=54321
