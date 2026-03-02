{ pkgs }:
with pkgs; [
  bashInteractive
  gnumake
  git
  openssl
  apacheHttpd    # htpasswd
  jq
  curl
  moreutils      # sponge
  inotify-tools  # inotifywait
  gettext        # envsubst
  ipcalc
  uv
  openssh
  docker-client
  python3
  sops
  age
  cacert
  gnutar
  gzip
  coreutils
  findutils
  gnugrep
  gnused
  gawk
]
