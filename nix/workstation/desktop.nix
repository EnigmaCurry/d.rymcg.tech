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

  # Firefox system-level policies (locked, cannot be changed in GUI)
  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisablePocket = true;
      DisableFirefoxStudies = true;
      DisableFirefoxScreenshots = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      NewTabPage = false;
      FirefoxHome = {
        Search = false;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
        Locked = true;
      };
      UserMessaging = {
        WhatsNew = false;
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
        MoreFromMozilla = false;
        Locked = true;
      };
    };
  };

  # Flatpak (flathub remote + packages configured via home-manager)
  services.flatpak.enable = true;

  # Thunar file manager with volume management
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [ thunar-volman thunar-archive-plugin ];
  };
  services.gvfs.enable = true;  # trash, network mounts, etc.

  # Allow user graphical sessions
  hardware.graphics.enable = true;
}
