{ config, pkgs, ... }:

{
  programs.powerline-go = {
    enable = true;
    newline = true;
    extraUpdatePS1 = ''
      PS1=$PS1;
    '';
  };
}
