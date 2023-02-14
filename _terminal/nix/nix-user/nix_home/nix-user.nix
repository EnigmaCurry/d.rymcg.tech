{ config, pkgs, ... }:

# NB the files in nix_home are copied into the image at ~/.config/nixpkgs/
# The nixpkgs directory is also copied to the same location.
# So you should reference imports as a relative path of the nixpkgs directory as if they all exist in the same directory:
{
  imports = [ ./common.nix ];
  home.packages = [
    pkgs.cowsay
  ];

  programs.bash = {
    enable = true;
    bashrcExtra = ''
    PS1='\[\e[0m\][\[\e[0;38;5;226;48;5;16m\]\u\[\e[0;94;48;5;16m\]@\[\e[0;3;38;5;160;48;5;16m\]\H\[\e[0m\]]\[\e[0m\] ''$ '
    export PATH=''${HOME}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:''${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user

    #### To enable BASH shell completion support for d.rymcg.tech,
    #### add the following lines into your ~/.bashrc ::
    export PATH=''${PATH}:''${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
    eval "''$(d.rymcg.tech completion bash)"

    #### Optional aliases you may wish to uncomment:
    #### If you want to quickly access a sub-project you can do that too:
    #### For example, instead of running this long command:
    ####   make -C ~/git/vendor/enigmacurry/d.rymcg.tech/traefik config
    #### Now you can run just: traefik config
    #### You can do this for any sub-project name:
    # __d.rymcg.tech_project_alias traefik

    #### If you have external projects, you can create an alias for those too:
    #### Also add the full path to the external project:
    #### For example, external project 'foo' in the directory ~/git/foo
    # __d.rymcg.tech_project_alias foo ~/git/foo

    #### If you want a shorter alias than d.rymcg.tech (eg. 'dry') you can add it:
    # __d.rymcg.tech_cli_alias dry

    cowsay "Welcome to Nix"
    '';
  };
}