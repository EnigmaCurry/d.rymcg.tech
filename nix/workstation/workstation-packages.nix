# All packages required for d.rymcg.tech operation + development tools
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # === d.rymcg.tech REQUIRED_COMMANDS (agent.py:359-362) ===
    bashInteractive   # bash
    gnumake           # make
    git               # git
    openssl           # openssl
    apacheHttpd       # htpasswd
    xdg-utils         # xdg-open
    jq                # jq
    sshfs             # sshfs
    wireguard-tools   # wg
    curl              # curl
    inotify-tools     # inotifywait
    w3m               # w3m
    moreutils         # sponge
    keychain          # keychain
    ipcalc            # ipcalc
    uv                # uv (Python package manager)
    # docker is provided by virtualisation.docker.enable

    # === Development tools (from nixos-vm-template dev.nix) ===
    neovim
    tmux
    ripgrep
    fd
    tree
    gettext
    asciinema
    imagemagick
    wget
    netcat
    pkg-config

    # === Additional development tools ===
    just
    htop
    file
    unzip
    zip
    p7zip

    # === Workstation/USB-specific tools ===
    parted
    gptfdisk
    dosfstools
    pv
    rsync
    ddrescue
    cloud-utils  # growpart
    e2fsprogs    # resize2fs

    # === Browser ===
    firefox

    # === Nix tools ===
    nix-output-monitor
    nixos-rebuild
  ];
}
