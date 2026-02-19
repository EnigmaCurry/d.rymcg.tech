# Git repo symlinks via home-manager home.file
# Creates read-only nix store symlinks so all repos are available offline
{ config, lib, pkgs, self, sway-home-src, swayHomeInputs, org-src, ... }:

{
  home-manager.users.user = { ... }: {
    home.file = {
      # d.rymcg.tech (self = flake source, excludes _archive/)
      "git/vendor/enigmacurry/d.rymcg.tech" = {
        source = self;
        recursive = true;
      };

      # sway-home (full repo, not the home-manager subdir)
      "git/vendor/enigmacurry/sway-home" = {
        source = sway-home-src;
        recursive = true;
      };

      # emacs (from sway-home's inputs)
      "git/vendor/enigmacurry/emacs" = {
        source = swayHomeInputs.emacs_enigmacurry;
        recursive = true;
      };

      # blog.rymcg.tech (from sway-home's inputs)
      "git/vendor/enigmacurry/blog.rymcg.tech" = {
        source = swayHomeInputs.blog-rymcg-tech;
        recursive = true;
      };

      # org (personal org-mode files)
      "git/vendor/enigmacurry/org" = {
        source = org-src;
        recursive = true;
      };

      # nixos-vm-template is already handled by sway-home.homeModules.nixos-vm-template
    };
  };
}
