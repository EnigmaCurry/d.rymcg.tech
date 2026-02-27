# Build context must be the d.rymcg.tech root directory.
# Build with: docker build -f nix/docker/Dockerfile -t d-rymcg-tech .

FROM nixos/nix:latest

COPY nix/docker/packages.nix /tmp/packages.nix

RUN NIX_BUILD=$(readlink $(which nix-build)) NIX_ENV=$(readlink $(which nix-env)) \
 && export NIX_SSL_CERT_FILE=$(readlink -f /root/.nix-profile/etc/ssl/certs/ca-bundle.crt) \
 && $NIX_ENV -e '.*' \
 && RESULT=$($NIX_BUILD --no-out-link -E 'let pkgs = import <nixpkgs> {}; in pkgs.buildEnv { name = "ci-packages"; paths = import /tmp/packages.nix { inherit pkgs; }; }') \
 && $NIX_ENV -i "$RESULT"

ENV PATH="/root/.nix-profile/bin:${PATH}"
ENV SSL_CERT_FILE="/root/.nix-profile/etc/ssl/certs/ca-bundle.crt"
ENV NIX_SSL_CERT_FILE="/root/.nix-profile/etc/ssl/certs/ca-bundle.crt"

# Install script-wizard from .tools.lock.json
COPY .tools.lock.json /tmp/.tools.lock.json
RUN export PATH="/root/.nix-profile/bin:${PATH}"; set -e; \
    VERSION=$(jq -r '.dependencies["script-wizard"].version' /tmp/.tools.lock.json); \
    curl -fsSL "https://github.com/EnigmaCurry/script-wizard/releases/download/v${VERSION}/script-wizard-Linux-x86_64.tar.gz" \
      | tar xz -C /root/.nix-profile/bin; \
    rm /tmp/.tools.lock.json

# Symlink /bin/bash for scripts with #!/bin/bash shebangs
RUN ln -sf /root/.nix-profile/bin/bash /bin/bash

# Copy the d.rymcg.tech repo
COPY . /home/user/git/vendor/enigmacurry/d.rymcg.tech
WORKDIR /home/user/git/vendor/enigmacurry/d.rymcg.tech

COPY nix/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
