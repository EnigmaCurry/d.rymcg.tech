FROM node:22 as build
WORKDIR /src
ARG GIT_REPO=https://git.v0l.io/Kieran/snort
ARG GIT_BRANCH=main
RUN apt update \
    && apt install -y --no-install-recommends git \
    && git clone --single-branch -b ${GIT_BRANCH} ${GIT_REPO} snort \
    && cd snort \
    && yarn --network-timeout 1000000 \
    && yarn build

FROM nginxinc/nginx-unprivileged:mainline-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/snort/packages/app/build /usr/share/nginx/html
