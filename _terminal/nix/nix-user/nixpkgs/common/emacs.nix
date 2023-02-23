{ config, pkgs, ... }:

let
  HOME = builtins.getEnv "HOME";
in {
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [
      epkgs.vterm
    ];
  };

  # EnigmaCurry emacs config
  home.activation.clone_emacs_config = ''
    CLONE=${HOME}/git/vendor/enigmacurry/emacs
    REPO=https://github.com/enigmacurry/emacs.git
    if [ ! -d "${HOME}/.emacs.d" ]; then
      echo "## Cloning $REPO ... "
      $DRY_RUN_CMD /usr/bin/git clone $REPO $CLONE
      mkdir ${HOME}/.emacs.d && ls -1 $CLONE/*.el | xargs -iXX ln -s XX ${HOME}/.emacs.d
      mkdir ${HOME}/.emacs.d/straight && ln -s $CLONE/straight-versions ${HOME}/.emacs.d/straight/versions
    else
      echo "## Already cloned $CLONE."
    fi
  '';
}
