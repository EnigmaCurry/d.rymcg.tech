# Home-manager integration using sway-home modules
# Follows the pattern from nixos-vm-template/profiles/home-manager.nix
{ config, lib, pkgs, sway-home, swayHomeInputs, nix-flatpak, firefox-addons, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    # Pass inputs that sway-home modules expect
    extraSpecialArgs = {
      inputs = swayHomeInputs;
      userName = "user";
    };

    # Configure home-manager for the regular user
    users.user = { pkgs, ... }:
    let
      # Pre-compiled vterm native module — NixOS can't build it via straight.el
      # because cmake can't find standard library paths in the nix store.
      # Installs vterm-module.so into the user profile's share/emacs/site-lisp/
      # which is on emacs's default load-path.
      emacs-vterm-module = pkgs.runCommand "emacs-vterm-module" {} ''
        mkdir -p $out/share/emacs/site-lisp
        find ${pkgs.emacsPackages.vterm} -name 'vterm-module.so' \
          -exec cp {} $out/share/emacs/site-lisp/ \;
      '';
    in
    {
      imports = [
        nix-flatpak.homeManagerModules.nix-flatpak
        sway-home.homeModules.home
        sway-home.homeModules.emacs
        sway-home.homeModules.rust
        sway-home.homeModules.nixos-vm-template
      ];

      # Flatpak: configure unconditionally (sway-home's module uses
      # builtins.pathExists which checks the build host, not the target)
      services.flatpak = {
        enable = true;
        remotes = [
          { name = "flathub"; location = "https://dl.flathub.org/repo/flathub.flatpakrepo"; }
        ];
        packages = [
          "io.github.kolunmi.Bazaar"
        ];
        update.onActivation = true;
      };

      # Install packages from sway-home + home-manager CLI (mutable system)
      home.packages = import "${sway-home}/modules/packages.nix" { inherit pkgs; }
        ++ [ swayHomeInputs.script-wizard.packages.${pkgs.stdenv.hostPlatform.system}.default ]
        ++ [ pkgs.home-manager ]
        ++ [ emacs-vterm-module ];

      programs.home-manager.enable = true;

      # Firefox profile config (package installed + policies set in desktop.nix)
      programs.firefox = {
        enable = true;
        package = null;  # don't install a second copy; system Firefox from desktop.nix

        profiles.default = {
          isDefault = true;

          extensions.packages = with firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
            ublock-origin
            darkreader
            vimium
            multi-account-containers
            temporary-containers
          ];

          # Search: DuckDuckGo only, hide all corporate engines
          search = {
            force = true;
            default = "ddg";
            privateDefault = "ddg";
            order = [ "ddg" ];
            engines = {
              "google".metaData.hidden = true;
              "bing".metaData.hidden = true;
              "amazondotcom-us".metaData.hidden = true;
              "ebay".metaData.hidden = true;
              "wikipedia".metaData.hidden = true;
              "perplexity".metaData.hidden = true;
              "ddg".metaData.alias = "@ddg";
            };
          };

          settings = {
            # === Dark mode ===
            "layout.css.prefers-color-scheme.content-override" = 0;
            "browser.theme.content-theme" = 0;
            "browser.theme.toolbar-theme" = 0;
            "ui.systemUsesDarkTheme" = 1;
            "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";

            # === Startup: restore previous session, blank new tab ===
            "browser.startup.homepage" = "about:blank";
            "browser.startup.page" = 3;
            "browser.newtabpage.enabled" = false;
            "browser.newtabpage.activity-stream.showSponsored" = false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
            "browser.newtabpage.activity-stream.feeds.topsites" = false;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
            "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
            "browser.newtabpage.activity-stream.feeds.snippets" = false;
            "browser.newtabpage.activity-stream.default.sites" = "";

            # === Disable telemetry ===
            "toolkit.telemetry.enabled" = false;
            "toolkit.telemetry.unified" = false;
            "toolkit.telemetry.server" = "";
            "toolkit.telemetry.archive.enabled" = false;
            "toolkit.telemetry.newProfilePing.enabled" = false;
            "toolkit.telemetry.shutdownPingSender.enabled" = false;
            "toolkit.telemetry.updatePing.enabled" = false;
            "toolkit.telemetry.bhrPing.enabled" = false;
            "toolkit.telemetry.firstShutdownPing.enabled" = false;
            "toolkit.telemetry.coverage.opt-out" = true;
            "toolkit.coverage.opt-out" = true;
            "toolkit.coverage.endpoint.base" = "";
            "datareporting.healthreport.uploadEnabled" = false;
            "datareporting.policy.dataSubmissionEnabled" = false;
            "app.shield.optoutstudies.enabled" = false;
            "app.normandy.enabled" = false;
            "app.normandy.api_url" = "";
            "browser.ping-centre.telemetry" = false;
            "breakpad.reportURL" = "";
            "browser.tabs.crashReporting.sendReport" = false;
            "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;

            # === Disable Pocket and sponsored content ===
            "extensions.pocket.enabled" = false;
            "browser.urlbar.suggest.quicksuggest.sponsored" = false;
            "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;

            # === Search suggestions ===
            "browser.search.suggest.enabled" = false;
            "browser.urlbar.suggest.searches" = false;
            "browser.urlbar.suggest.engines" = false;

            # === History: clear on restart, keep bookmarks ===
            "privacy.sanitize.sanitizeOnShutdown" = true;
            "privacy.clearOnShutdown_v2.historyFormDataAndDownloads" = true;
            "privacy.clearOnShutdown_v2.cookiesAndStorage" = true;
            "privacy.clearOnShutdown_v2.cache" = true;
            "privacy.clearOnShutdown_v2.siteSettings" = false;
            "places.history.enabled" = false;

            # === Privacy ===
            "browser.contentblocking.category" = "strict";
            "privacy.trackingprotection.enabled" = true;
            "privacy.trackingprotection.socialtracking.enabled" = true;
            "privacy.trackingprotection.cryptomining.enabled" = true;
            "privacy.trackingprotection.fingerprinting.enabled" = true;
            "extensions.formautofill.addresses.enabled" = false;
            "extensions.formautofill.creditCards.enabled" = false;
            "signon.rememberSignons" = false;

            # === HTTPS-only mode ===
            "dom.security.https_only_mode" = true;
            "dom.security.https_only_mode_ever_enabled" = true;

            # === Extensions: auto-enable without user approval ===
            "extensions.autoDisableScopes" = 0;

            # === UI cleanup ===
            "browser.shell.checkDefaultBrowser" = false;
            "browser.aboutConfig.showWarning" = false;
            "browser.startup.homepage_override.mstone" = "ignore";
            "media.autoplay.default" = 5;
          };
        };
      };
    };
  };
}
