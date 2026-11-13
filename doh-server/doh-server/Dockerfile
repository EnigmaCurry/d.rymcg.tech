ARG RUST_IMAGE
FROM ${RUST_IMAGE} AS build
ARG DOH_PROXY_VERSION
## --locked uses the crate's own Cargo.lock, so dependency releases can't
## break the build (e.g. ones requiring a newer Rust edition):
RUN cargo install doh-proxy --version "${DOH_PROXY_VERSION}" --locked --no-default-features

FROM debian:bookworm-slim
COPY --from=build /usr/local/cargo/bin/doh-proxy /usr/local/bin/doh-proxy
USER nobody
EXPOSE 3000
