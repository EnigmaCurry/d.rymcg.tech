# Build context must be the d.rymcg.tech root directory.
# Build with: docker build -f nix/docker/Dockerfile -t d-rymcg-tech-ci .

FROM nixos/nix:latest AS builder

COPY nix/docker/packages.nix /tmp/packages.nix

RUN nix-env -iA nixpkgs.cacert \
 && nix-env -if '<nixpkgs>' -E 'pkgs: import /tmp/packages.nix { inherit pkgs; }'

FROM nixos/nix:latest

COPY --from=builder /nix/store /nix/store
COPY --from=builder /root/.nix-profile /root/.nix-profile
ENV PATH="/root/.nix-profile/bin:${PATH}"
ENV SSL_CERT_FILE="/root/.nix-profile/etc/ssl/certs/ca-bundle.crt"
ENV NIX_SSL_CERT_FILE="/root/.nix-profile/etc/ssl/certs/ca-bundle.crt"

# Install script-wizard from .tools.lock.json
COPY .tools.lock.json /tmp/.tools.lock.json
RUN set -e; \
    VERSION=$(jq -r '.dependencies["script-wizard"].version' /tmp/.tools.lock.json); \
    curl -fsSL "https://github.com/EnigmaCurry/script-wizard/releases/download/v${VERSION}/script-wizard-Linux-x86_64.tar.gz" \
      | tar xz -C /usr/local/bin; \
    rm /tmp/.tools.lock.json

# Copy the d.rymcg.tech repo
COPY . /home/user/git/vendor/enigmacurry/d.rymcg.tech
WORKDIR /home/user/git/vendor/enigmacurry/d.rymcg.tech

COPY nix/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
