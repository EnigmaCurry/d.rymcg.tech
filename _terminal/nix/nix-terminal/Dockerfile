FROM debian:bullseye-slim as home-manager-base
ARG NIX_USER_NAME=nix-user
ARG NIX_USER_UID=1000
ARG NIX_USER_GID=1000
RUN mkdir -p /home/${NIX_USER_NAME}/.config/environment.d && \
    addgroup --gid ${NIX_USER_GID} ${NIX_USER_NAME} && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl xz-utils && \
    adduser --no-create-home --uid ${NIX_USER_UID} \
      --gid ${NIX_USER_GID} ${NIX_USER_NAME} --gecos GECOS --disabled-password && \
    mkdir /nix && \
    chown -R ${NIX_USER_UID}:${NIX_USER_GID} /nix /home/${NIX_USER_NAME}

USER ${NIX_USER_NAME}
WORKDIR /home/${NIX_USER_NAME}
ENV USER=${NIX_USER_NAME}
ENV PATH=/home/${NIX_USER_NAME}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} nixpkgs /home/${NIX_USER_NAME}/.config/nixpkgs
RUN curl -L https://nixos.org/nix/install | sh && \
    nix-channel --add \
      https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && \
    nix-channel --update && \
    nix-shell '<home-manager>' -A install && \
    home-manager switch
COPY --chown=${NIX_USER_UID}:${NIX_USER_GID} bashrc /home/${NIX_USER_NAME}/.bashrc

CMD /bin/sh -c 'while true; do sleep 3; done;'
