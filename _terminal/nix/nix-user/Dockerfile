FROM debian:bullseye-slim as home-manager-base
ARG NIX_USER_NAME=nix-user
ARG NIX_USER_UID=1000
ARG NIX_USER_GID=1000
ARG NIX_HOMEMANAGER_BASE=common.nix
RUN addgroup --gid ${NIX_USER_GID} ${NIX_USER_NAME} && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl xz-utils && \
    adduser --uid ${NIX_USER_UID} \
      --gid ${NIX_USER_GID} ${NIX_USER_NAME} --gecos GECOS --disabled-password && \
    mkdir /nix && \
    chown -R ${NIX_USER_UID}:${NIX_USER_GID} /nix

USER ${NIX_USER_NAME}
WORKDIR /home/${NIX_USER_NAME}
ENV USER=${NIX_USER_NAME}
ENV PATH=/home/${NIX_USER_NAME}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} nixpkgs .config/nixpkgs
RUN cp .config/nixpkgs/${NIX_HOMEMANAGER_BASE} .config/nixpkgs/home.nix && \
    curl -L https://nixos.org/nix/install | sh && \
    nix-channel --add \
      https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && \
    nix-channel --update && \
    nix-shell '<home-manager>' -A install && \
    rm -f .config/nixpkgs/home.nix && \
    rm -f .bashrc .profile && \
    mkdir git
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} nix_home/* .config/nixpkgs/
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} entrypoint.sh bin/entrypoint
RUN chmod a+x bin/entrypoint
ENTRYPOINT /home/${NIX_USER_NAME}/bin/entrypoint
