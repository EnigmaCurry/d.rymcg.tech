FROM ghcr.io/enigmacurry/ubuntu-dind
WORKDIR /actions-runner
ARG VERSION=2.286.1
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y git && \
    curl -o actions-runner-linux-x64-${VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz && \
    tar xzf ./actions-runner-linux-x64-${VERSION}.tar.gz && \
    rm ./actions-runner-linux-x64-${VERSION}.tar.gz && \
    useradd -m user && \
    chown -R user:user /actions-runner && \
    ./bin/installdependencies.sh
ADD --chmod=555 run.sh /usr/local/bin/

USER user

ENTRYPOINT /usr/local/bin/run.sh
