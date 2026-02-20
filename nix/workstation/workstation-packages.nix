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

    # === Development tools ===
    neovim
    tmux
    ripgrep
    fd
    tree
    gettext
    asciinema
    imagemagick
    wget
    pkg-config
    cmake
    gnupatch

    # === Additional development tools ===
    just
    htop
    file
    unzip
    zip
    p7zip

    # === Network diagnostics ===
    nmap
    netcat
    dnsutils          # dig, nslookup
    traceroute
    tcpdump
    ethtool
    iperf3
    whois
    mtr               # traceroute + ping combined
    socat
    step-cli          # step-ca CLI for ACME / PKI
    step-ca           # private ACME CA server
    rclone            # cloud/remote file sync

    # === Crypto / security ===
    gnupg
    age
    pass
    pinentry-curses

    # === Workstation/USB-specific tools ===
    parted
    gptfdisk
    dosfstools
    pv
    rsync
    ddrescue
    cloud-utils       # growpart
    e2fsprogs         # resize2fs
    usbutils          # lsusb
    pciutils          # lspci
    smartmontools     # smartctl (disk health)
    testdisk          # partition/file recovery
    ntfs3g            # mount Windows drives
    minicom           # serial console
    picocom           # lightweight serial console
    ipmitool          # server BMC management

    # === Desktop (sway ecosystem) ===
    # Firefox is configured via home-manager in home-manager.nix (with extensions)
    networkmanagerapplet  # nm-applet tray icon for sway
    kanshi                # auto display management
    mako                  # desktop notifications
    lxsession             # polkit agent (auth prompts for virt-manager, etc.)
    grim                  # screenshot tool
    slurp                 # screen region selector (pairs with grim)
    wl-clipboard          # wl-copy/wl-paste
    swaylock              # screen locker
    swayidle              # idle management
    pavucontrol           # PipeWire volume control GUI
    brightnessctl         # laptop backlight control
    dex                   # autostart .desktop files
    blueman               # Bluetooth tray manager
    pcmanfm               # GUI file manager
    imv                   # Wayland image viewer
    zathura               # PDF viewer
    mpv                   # media player
    wev                   # Wayland event viewer (debug input)

    # === Python ===
    python3
    python3Packages.pip
    python3Packages.virtualenv

    # === Rust (rustup is in sway-home, these are build deps) ===
    rustup
    gcc
    clang
    llvmPackages.bintools

    # === Virtualization ===
    virt-manager
    qemu_kvm
    OVMF              # UEFI firmware for VMs
    swtpm             # TPM emulator

    # === Nix tools ===
    nix-output-monitor
    nixos-rebuild
  ];
}
