{ config, pkgs, ... }:
let
  HOME = builtins.getEnv "HOME";
  NIX_GIT_D_RYMCG_TECH_CLONE = builtins.getEnv "NIX_GIT_D_RYMCG_TECH_CLONE";
  NIX_GIT_D_RYMCG_TECH_REPO = builtins.getEnv "NIX_GIT_D_RYMCG_TECH_REPO";
in {
  # d.rymcg.tech
  home.activation.clone_d_rymcg_tech = ''
    if [ ! -d "${HOME}/${NIX_GIT_D_RYMCG_TECH_CLONE}" ]; then
      echo "## Cloning ${NIX_GIT_D_RYMCG_TECH_REPO} ... "
      $DRY_RUN_CMD /usr/bin/git clone ${NIX_GIT_D_RYMCG_TECH_REPO} ${HOME}/${NIX_GIT_D_RYMCG_TECH_CLONE}
    else
      echo "## Already cloned ${NIX_GIT_D_RYMCG_TECH_CLONE}."
    fi
  '';
}
