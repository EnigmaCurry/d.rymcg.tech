#!/bin/bash

GIT_CLONE="${GIT_CLONE:-${HOME}/git/vendor/enigmacurry/d.rymcg.tech}"
GIT_REPO="${GIT_REPO:-https://github.com/EnigmaCurry/d.rymcg.tech.git}"
GIT_BRANCH="${GIT_BRANCH}"

test -e ${HOME}/git/vendor/enigmacurry/d.rymcg.tech || \
    (git clone "${GIT_REPO}" "${GIT_CLONE}" && \
         test -n "${GIT_BRANCH}" && \
         git checkout "${GIT_BRANCH}")

/bin/sh -c 'while true; do sleep 3; done;'
