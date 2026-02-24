# Workstation settings — edit this file to customize your system.
# After editing, rebuild with: sudo nixos-rebuild switch
#
# To hide local changes from git status:
#   git update-index --skip-worktree nix/workstation/settings.nix
#
# To undo:
#   git update-index --no-skip-worktree nix/workstation/settings.nix
{
  hostName = "workstation";
  userName = "user";
  sudoUser = true;
  remotes = {
    "d.rymcg.tech" = "https://github.com/EnigmaCurry/d.rymcg.tech.git";
    "sway-home" = "https://github.com/EnigmaCurry/sway-home.git";
    "emacs" = "https://github.com/EnigmaCurry/emacs.git";
    "blog.rymcg.tech" = "https://github.com/EnigmaCurry/blog.rymcg.tech.git";
    "org" = "https://github.com/EnigmaCurry/org.git";
  };
}
