#
# ~/.bashrc
#

PS1='[\u@\h \W]\$ '
PATH=${PATH}:${HOME}/bin
EDITOR=emacsclient

eval $(keychain --eval --quiet)

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias bb='rlwrap bb'


vterm_printf() {
    if [ -n "$TMUX" ] && ([ "${TERM%%-*}" = "tmux" ] || [ "${TERM%%-*}" = "screen" ]); then
        # Tell tmux to pass the escape sequences through
        printf "\ePtmux;\e\e]%s\007\e\\" "$1"
    elif [ "${TERM%%-*}" = "screen" ]; then
        # GNU screen (screen, screen-256color, screen-256color-bce)
        printf "\eP\e]%s\007\e\\" "$1"
    else
        printf "\e]%s\e\\" "$1"
    fi
}
if [[ "$INSIDE_EMACS" = 'vterm' ]]; then
    function clear() {
        vterm_printf "51;Evterm-clear-scrollback";
        tput clear;
    }
fi
vterm_prompt_end(){
    vterm_printf "51;A$(whoami)@$(hostname):$(pwd)"
}
PS1=$PS1'\[$(vterm_prompt_end)\]'


#### To enable Bash shell completion support for d.rymcg.tech,
#### add the following lines into your ~/.bashrc ::
export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user

if [[ -d ${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user ]]; then
    eval "$(d.rymcg.tech completion bash)"
    ## Example project alias: creates a shorter command used just for the Traefik project:
    __d.rymcg.tech_project_alias traefik
fi
