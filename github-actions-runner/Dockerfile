FROM ghcr.io/enigmacurry/ubuntu-dind
WORKDIR /actions-runner
ARG VERSION=2.317.0
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y git build-essential make libc6 libicu-dev && \
    curl -o actions-runner-linux-x64-${VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz && \
    tar xzf ./actions-runner-linux-x64-${VERSION}.tar.gz && \
    rm ./actions-runner-linux-x64-${VERSION}.tar.gz && \
    useradd -m user && \
    chown -R user:user /actions-runner && \
    ./bin/installdependencies.sh

ADD --chmod=555 run.sh /usr/local/bin/

USER user
## Rust tools:
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . ~/.cargo/env && \
    rustup toolchain install stable && \
    rustup target add wasm32-unknown-unknown

ENTRYPOINT /usr/local/bin/run.sh
