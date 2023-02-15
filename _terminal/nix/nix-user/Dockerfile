ARG DOCKER_IMAGE
FROM ${DOCKER_IMAGE} as home-manager-base
ARG DOCKER_IMAGE
ARG NIX_USER_NAME=nix-user
ARG NIX_USER_UID=1000
ARG NIX_USER_GID=1000
ENV DOCKER_IMAGE=${DOCKER_IMAGE}
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
ARG NIX_HOMEMANAGER_VERSION
ENV NIX_USER_NAME=${NIX_USER_NAME} NIX_HOMEMANAGER_VERSION=${NIX_HOMEMANAGER_VERSION}
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} nixpkgs/base.nix nixpkgs/common.nix .config/nixpkgs/
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} nixpkgs/base/* .config/nixpkgs/base/
RUN cp -f .config/nixpkgs/common.nix .config/nixpkgs/home.nix && \
    curl -L https://nixos.org/nix/install | sh && \
    nix-channel --add \
      https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && \
    nix-channel --update && \
    nix-shell '<home-manager>' -A install && \
    rm -f .config/nixpkgs/home.nix && \
    rm -f .bashrc .profile && \
    mkdir git
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} nixpkgs/user .config/nixpkgs/user
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} nixpkgs/home.nix .config/nixpkgs/home.nix
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} entrypoint.sh bin/entrypoint
RUN chmod a+x bin/entrypoint
ENTRYPOINT /home/${NIX_USER_NAME}/bin/entrypoint
