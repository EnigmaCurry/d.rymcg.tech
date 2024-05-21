#!/bin/bash

set -e

stderr(){ echo "$@" >/dev/stderr; }
error(){ stderr "Error: $@"; }
fault(){ test -n "$1" && error $1; stderr "Exiting."; exit 1; }
confirm() {
    test ${YES:-no} == "yes" && exit 0
    local default=$1; local prompt=$2; local question=${3:-". Proceed?"}
    if [[ $default == "y" || $default == "yes" || $default == "ok" ]]; then
        dflt="Y/n"
    else
        dflt="y/N"
    fi

    read -e -p "${prompt}${question} (${dflt}): " answer
    answer=${answer:-${default}}

    if [[ ${answer,,} == "y" || ${answer,,} == "yes" || ${answer,,} == "ok" ]]; then
        return 0
    else
        return 1
    fi

}

[[ "$(git rev-parse --abbrev-ref HEAD)" == "gh-pages-blank" ]] || fault "Sorry, to run this script, you must switch to the gh-pages-blank branch first."

confirm no "Do you want to reindex, rebuild, rebase, and force push to the static gh-pages site" "?"

cd $(realpath $(dirname ${BASH_SOURCE}))
pwd

[[ -z "$(git status -s | grep -v "^?")" ]] || fault "Sorry I can't do that without a
clean git status. Commit or stash your uncommitted changes before
proceeding."

get_packages() {
    curl https://api.github.com/repos/EnigmaCurry/d.rymcg.tech/git/trees/master | \
        jq -r '.tree[] | select(.type == "tree")' | \
        jq -r .path | \
        grep -v "^_"
}

git fetch origin
git branch -D gh-pages
git checkout -b gh-pages origin/gh-pages
git reset --hard origin/gh-pages-blank

get_packages | while read -r package; do
    mkdir -p "${package}"
    cat <<EOF > "${package}/index.html"
<html>
    <head>
        <meta http-equiv="refresh" content="0; url=https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/${package}#readme" />
    </head>
    <body>
        Redirecting to <a href="https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/${package}#readme">https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/${package}#readme</a>
    </body>
</html>
EOF
    git add "${package}/index.html"
done

git commit -m "Reindex packages"
git push -u origin gh-pages --force
git checkout gh-pages-blank
