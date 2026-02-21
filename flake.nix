{
  description = "d.rymcg.tech - Docker server infrastructure and workstation USB image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sway-home = {
      url = "github:EnigmaCurry/sway-home?dir=home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Full sway-home repo (the sway-home input above is just the home-manager subdir)
    sway-home-src = {
      url = "github:EnigmaCurry/sway-home";
      flake = false;
    };
    # Repos not already available via sway-home.inputs
    org-src = {
      url = "github:EnigmaCurry/org";
      flake = false;
    };

    # Bare git repos for offline workstation (overridden at build time)
    vendor-git-repos = {
      url = "github:EnigmaCurry/d.rymcg.tech";  # placeholder, overridden at build time
      flake = false;
    };

    # Firefox extensions
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sway-home, nix-flatpak
    , sway-home-src, org-src, vendor-git-repos, firefox-addons, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Access sway-home's own inputs (emacs, blog, nixos-vm-template, etc.)
      swayHomeInputs = sway-home.inputs;
    in
    {
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit self sway-home swayHomeInputs nix-flatpak;
          inherit sway-home-src org-src vendor-git-repos firefox-addons;
        };
        modules = [
          home-manager.nixosModules.home-manager
          ./nix/workstation/configuration.nix
        ];
      };
    };
}
