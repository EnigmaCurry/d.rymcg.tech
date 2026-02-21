# Git repo symlinks via home-manager home.file
# Creates read-only nix store symlinks so all repos are available offline.
# When vendor-git-repos is overridden at build time with bare clones (full history),
# those are used directly. Otherwise, synthetic single-commit bare repos are created as fallback.
{ config, lib, pkgs, self, sway-home-src, swayHomeInputs, org-src, vendor-git-repos, ... }:

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

  bareRepos = {
    "d.rymcg.tech" = getBareRepo "d.rymcg.tech" self;
    "sway-home" = getBareRepo "sway-home" sway-home-src;
    "emacs" = getBareRepo "emacs" swayHomeInputs.emacs_enigmacurry;
    "blog.rymcg.tech" = getBareRepo "blog.rymcg.tech" swayHomeInputs.blog-rymcg-tech;
    "org" = getBareRepo "org" org-src;
  };
in
{
  home-manager.users.user = { ... }: {
    home.file = {
      # d.rymcg.tech
      "git/vendor-nix/enigmacurry/d.rymcg.tech" = {
        source = bareRepos."d.rymcg.tech";
        recursive = true;
      };

      # sway-home
      "git/vendor-nix/enigmacurry/sway-home" = {
        source = bareRepos."sway-home";
        recursive = true;
      };

      # emacs
      "git/vendor-nix/enigmacurry/emacs" = {
        source = bareRepos."emacs";
        recursive = true;
      };

      # blog.rymcg.tech
      "git/vendor-nix/enigmacurry/blog.rymcg.tech" = {
        source = bareRepos."blog.rymcg.tech";
        recursive = true;
      };

      # org
      "git/vendor-nix/enigmacurry/org" = {
        source = bareRepos."org";
        recursive = true;
      };

      # nixos-vm-template is already handled by sway-home.homeModules.nixos-vm-template
    };

    home.sessionPath = [
      "/home/user/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user"
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
      User = "user";
      Group = "users";
    };
    script = ''
      dest="/home/user/git/vendor/enigmacurry/d.rymcg.tech"
      if [ ! -d "$dest/.git" ]; then
        echo "Cloning d.rymcg.tech from nix store..."
        mkdir -p /home/user/git/vendor/enigmacurry
        git clone ${bareRepos."d.rymcg.tech"} "$dest"
        git -C "$dest" remote set-url origin https://github.com/EnigmaCurry/d.rymcg.tech.git
        echo "d.rymcg.tech: cloned and remote set"
      else
        echo "d.rymcg.tech: already exists, skipping"
      fi
    '';
  };
}
