export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
if [[ "${NO_INSTALL}" != "true" ]]; then
    if test -d ${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user; then
        eval "$(d.rymcg.tech completion bash)"
    else
        echo "Installing d.rymcg.tech and dependencies now ..."
        /bin/bash /usr/local/template/d.rymcg.tech-workstation/install_d.rymcg.tech.sh
        eval "$(d.rymcg.tech completion bash)"
        echo "Finished installing d.rymcg.tech and all dependencies."
    fi
else
    echo "Not running d.rymcg.tech installer because this shell has set NO_INSTALL=true"
fi
