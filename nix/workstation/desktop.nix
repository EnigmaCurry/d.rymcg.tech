# Sway desktop environment with greetd login
{ config, lib, pkgs, ... }:

{
  # Sway window manager
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # Console login manager -> sway
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "greeter";
      };
    };
  };

  # PipeWire audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  # Required for PipeWire
  security.rtkit.enable = true;

  # XDG portals for sway
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    fira-code
    fira-code-symbols
    jetbrains-mono
    font-awesome
    liberation_ttf
    dejavu_fonts
  ];

  # Allow user graphical sessions
  hardware.graphics.enable = true;
}
