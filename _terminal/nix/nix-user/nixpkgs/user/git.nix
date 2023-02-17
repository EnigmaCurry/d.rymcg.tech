{ config, pkgs, ... }:

{
  # https://nix-community.github.io/home-manager/options.html#opt-programs.git.enable
  programs.git = {
    enable = true;
    userEmail = builtins.getEnv "NIX_GIT_EMAIL";
    userName = builtins.getEnv "NIX_GIT_USERNAME";
  };

  home.file = {
    # d.rymcg.tech
    "${homeDir}/git/vendor/enigmacurry/d.rymcg.tech".source = builtins.fetchGit {
      url = "https://github.com/enigmacurry/d.rymcg.tech.git";
      ref = "master";
    };
}
