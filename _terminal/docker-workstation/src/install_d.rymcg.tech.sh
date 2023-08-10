# FROM docker-ssh-base as d-rymcg-tech-workstation
# ARG GIT_REPO=https://github.com/EnigmaCurry/d.rymcg.tech.git GIT_BRANCH=master ROOT_DIR=/root/git/vendor/enigmacurry/d.rymcg.tech
# RUN git clone ${GIT_REPO} ${ROOT_DIR}; \
#     cd ${ROOT_DIR}; \
#     git checkout ${GIT_BRANCH}
# VOLUME /root
# WORKDIR ${ROOT_DIR}
# ADD bashrc.sh /root/.bashrc
