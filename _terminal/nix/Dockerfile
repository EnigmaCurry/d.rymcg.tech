FROM nixos/nix:latest as home-manager-base
ARG AUTHORIZED_KEYS_FILE=./authorized_keys
RUN nix-channel --add \
    https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && \
    nix-channel --update && \
    nix-env --set-flag priority 7 man-db && \
    nix-env --set-flag priority 7 coreutils-full && \
    nix-env --set-flag priority 7 findutils && \
    nix-shell '<home-manager>' -A install && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
COPY nixpkgs/base.nix /root/.config/nixpkgs/home.nix
RUN home-manager switch

FROM home-manager-base as home-manager-common
COPY nixpkgs /root/.config/nixpkgs
COPY nixpkgs/common.nix /root/.config/nixpkgs/home.nix
RUN home-manager switch
COPY bashrc /root/.bashrc
WORKDIR /root
VOLUME /root/git
