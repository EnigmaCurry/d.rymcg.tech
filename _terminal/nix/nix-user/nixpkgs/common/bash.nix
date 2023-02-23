{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.cowsay
  ];

  programs.bash = {
    enable = true;
    bashrcExtra = ''
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

    cowsay -f meow -W 49 "Welcome to ''${HOSTNAME} on ''${DOCKER_IMAGE:-unknown}. I am a pet container, and all data in /home/''${USER} is persisted to a docker volume."
    '';
  };
}
