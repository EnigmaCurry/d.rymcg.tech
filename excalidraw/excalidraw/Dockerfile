#FROM --platform=${BUILDPLATFORM} node:20 AS build
FROM node:20 AS build
WORKDIR /opt/node_app
RUN git clone https://github.com/excalidraw/excalidraw.git
# do not ignore optional dependencies:
# Error: Cannot find module @rollup/rollup-linux-x64-gnu
COPY package.json ./
RUN --mount=type=cache,target=/root/.cache/yarn \
    npm_config_target_arch=${TARGETARCH} yarn --network-timeout 600000
ARG NODE_ENV=production
RUN npm_config_target_arch=${TARGETARCH} yarn build:app:docker

FROM --platform=${TARGETPLATFORM} nginx:1.27-alpine
# Copy custom nginx config to change the port
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 8080
COPY --from=build /opt/node_app/excalidraw-app/build /usr/share/nginx/html
