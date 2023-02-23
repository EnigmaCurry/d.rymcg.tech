{ config, pkgs, ... }:

{
  programs.powerline-go = {
    enable = true;
    modules = [
      "venv"
      ## There's only one user account, so why show it?
      #"user"
      "host"
      "docker-context"
      "ssh"
      "cwd"
      "perms"
      "git"
      "hg"
      "jobs"
      "exit"
      "root"
    ];
    newline = false;
    extraUpdatePS1 = ''
    '';
    settings = {
      theme = "default";
      colorize-hostname = true;
      condensed = true;
    };
  };
}
