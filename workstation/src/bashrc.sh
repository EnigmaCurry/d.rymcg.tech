export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
alias install_d.rymcg.tech="/bin/bash /usr/local/template/d.rymcg.tech-workstation/install_d.rymcg.tech.sh"
MARKER_INDICATES_ALREADY_INSTALLED=${HOME}/.config/d.rymcg.tech/.already_installed
if test -f ${MARKER_INDICATES_ALREADY_INSTALLED}; then
    eval "$(d.rymcg.tech completion bash)"
else
    if [[ "${NO_INSTALL}" != "true" ]]; then
        echo "Installing d.rymcg.tech and dependencies now ..."
        install_d.rymcg.tech
        mkdir -p $(dirname ${MARKER_INDICATES_ALREADY_INSTALLED}) && touch ${MARKER_INDICATES_ALREADY_INSTALLED}
        eval "$(d.rymcg.tech completion bash)"
        echo "Finished installing d.rymcg.tech and all dependencies."
        cat /etc/motd
    else
        echo "Not running d.rymcg.tech installer because this shell has set NO_INSTALL=true"
        echo "To run the installer manually run: install_d.rymcg.tech"
    fi
fi
