# Git repo symlinks via home-manager home.file
# Creates read-only nix store symlinks so all repos are available offline.
# When vendor-git-repos is overridden at build time with bare clones (full history),
# those are used directly. Otherwise, synthetic single-commit bare repos are created as fallback.
{ config, lib, pkgs, self, sway-home-src, swayHomeInputs, org-src, vendor-git-repos, hostName, userName, remotes, ... }:

let
  # Create a single-commit bare repo from a source tree (fallback when vendor-git-repos isn't overridden)
  mkBareRepo = name: src: pkgs.runCommand "${name}-bare-repo" {
    nativeBuildInputs = [ pkgs.git ];
  } ''
    export HOME=$TMPDIR
    WORK=$(mktemp -d)
    cp -r ${src}/. "$WORK/"
    cd "$WORK"
    git init -b master --quiet
    git add .
    git -c user.email="nix@localhost" -c user.name="Nix" commit -m "Bundled source" --quiet
    git clone --bare "$WORK" "$out"
  '';

  # Detect whether vendor-git-repos contains real bare repos (overridden at build time)
  hasBareRepos = builtins.pathExists "${vendor-git-repos}/d.rymcg.tech/HEAD";

  # Get bare repo for a given name, falling back to synthetic bare repo from source
  getBareRepo = name: src:
    if hasBareRepos
    then "${vendor-git-repos}/${name}"
    else mkBareRepo name src;

  # Map repo names to their flake input sources
  repoSources = {
    "d.rymcg.tech" = self;
    "sway-home" = sway-home-src;
    "emacs" = swayHomeInputs.emacs_enigmacurry;
    "blog.rymcg.tech" = swayHomeInputs.blog-rymcg-tech;
    "org" = org-src;
  };

  bareRepos = lib.mapAttrs (name: src: getBareRepo name src) repoSources;

  repoNames = lib.attrNames remotes;

  # Generate home.file entries for vendor-nix symlinks
  vendorNixFiles = lib.listToAttrs (map (name: {
    name = "git/vendor-nix/enigmacurry/${name}";
    value = { source = bareRepos.${name}; };
  }) repoNames);

  # Generate the clone script from remotes
  cloneSnippet = name: url: ''
    dest="$base/${name}"
    if [ ! -d "$dest/.git" ]; then
      echo "Cloning ${name} from nix store..."
      git -c safe.directory='*' clone ${bareRepos.${name}} "$dest"
      git -C "$dest" remote set-url origin ${url}
  '' + lib.optionalString (name == "d.rymcg.tech") ''
      # Ensure settings.nix reflects the baked-in configuration
      sed -i 's/hostName = ".*"/hostName = "${hostName}"/' "$dest/nix/workstation/settings.nix"
      sed -i 's/userName = ".*"/userName = "${userName}"/' "$dest/nix/workstation/settings.nix"
      git -C "$dest" update-index --skip-worktree nix/workstation/settings.nix
  '' + ''
      echo "${name}: cloned and remote set"
    else
      echo "${name}: already exists, skipping"
    fi
  '';

  cloneScript = lib.concatStringsSep "\n" (lib.mapAttrsToList cloneSnippet remotes);

in
{
  home-manager.users.${userName} = { ... }: {
    home.file = vendorNixFiles;

    home.sessionPath = [
      "/home/${userName}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user"
    ];
  };

  # Clone writable repos from the nix store on first boot
  systemd.services.workstation-clone-repos = {
    description = "Clone writable git repos from nix store to ~/git/vendor/";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    path = [ pkgs.git ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = userName;
      Group = "users";
    };
    script = ''
      base="/home/${userName}/git/vendor/enigmacurry"
      mkdir -p "$base"

    '' + cloneScript;
  };

  # nixos-vm-template is already handled by sway-home.homeModules.nixos-vm-template
}
