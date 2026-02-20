# Git repo symlinks via home-manager home.file
# Creates read-only nix store symlinks so all repos are available offline.
# Each source is wrapped in a git repo so git commands work on the bundled copies.
{ config, lib, pkgs, self, sway-home-src, swayHomeInputs, org-src, ... }:

let
  # Wrap a source tree in a git repo so commands like git log/status/ls-tree work
  mkGitRepo = name: src: pkgs.runCommand "${name}-git-repo" {
    nativeBuildInputs = [ pkgs.git ];
  } ''
    cp -r ${src} $out
    chmod -R u+w $out
    cd $out
    export HOME=$TMPDIR
    git init -b master --quiet
    git add .
    git -c user.email="nix@localhost" -c user.name="Nix" commit -m "Bundled source" --quiet
    git remote add origin .
    git fetch origin --quiet
  '';
in
{
  home-manager.users.user = { ... }: {
    home.file = {
      # d.rymcg.tech (self = flake source, excludes _archive/)
      "git/vendor-nix/enigmacurry/d.rymcg.tech" = {
        source = mkGitRepo "d.rymcg.tech" self;
        recursive = true;
      };

      # sway-home (full repo, not the home-manager subdir)
      "git/vendor-nix/enigmacurry/sway-home" = {
        source = mkGitRepo "sway-home" sway-home-src;
        recursive = true;
      };

      # emacs (from sway-home's inputs)
      "git/vendor-nix/enigmacurry/emacs" = {
        source = mkGitRepo "emacs" swayHomeInputs.emacs_enigmacurry;
        recursive = true;
      };

      # blog.rymcg.tech (from sway-home's inputs)
      "git/vendor-nix/enigmacurry/blog.rymcg.tech" = {
        source = mkGitRepo "blog.rymcg.tech" swayHomeInputs.blog-rymcg-tech;
        recursive = true;
      };

      # org (personal org-mode files)
      "git/vendor-nix/enigmacurry/org" = {
        source = mkGitRepo "org" org-src;
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
    script = let
      src = mkGitRepo "d.rymcg.tech" self;
    in ''
      dest="/home/user/git/vendor/enigmacurry/d.rymcg.tech"
      if [ ! -d "$dest/.git" ]; then
        echo "Cloning d.rymcg.tech from nix store..."
        mkdir -p /home/user/git/vendor/enigmacurry
        cp -a ${src} "$dest"
        chmod -R u+w "$dest"
        git -C "$dest" remote set-url origin https://github.com/EnigmaCurry/d.rymcg.tech.git
        echo "d.rymcg.tech: cloned and remote set"
      else
        echo "d.rymcg.tech: already exists, skipping"
      fi
    '';
  };
}
