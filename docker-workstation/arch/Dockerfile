FROM archlinux as base_packages
ARG ARCH_MIRROR
RUN echo "Server = ${ARCH_MIRROR}"'/$repo/os/$arch' > /etc/pacman.d/mirrorlist
RUN pacman -Syyu --noconfirm --disable-download-timeout
ARG BASE_PACKAGES
RUN pacman -S --noconfirm --disable-download-timeout ${BASE_PACKAGES}

FROM base_packages as sshd-sudo-workstation
RUN pacman -S --noconfirm openssh sudo --disable-download-timeout
RUN mkdir -p /etc/ssh/keys && \
    sed -ie 's/^#\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen && \
    rm /etc/ssh/sshd_config
ADD sshd_config /etc/ssh/sshd_config
ARG USERNAME
ENV USERNAME=${USERNAME}
RUN useradd -mU -s /bin/bash "${USERNAME}" && \
    echo "${USERNAME}:$(openssl rand -base64 32)" | chpasswd && \
    echo "${USERNAME} ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${USERNAME}" && \
    echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config && \
    rm -f "/home/${USERNAME}/{.bashrc,.bash_profile}"

ADD bashrc.sh /etc/bash.bashrc
ADD profile.sh /etc/profile
EXPOSE 22
CMD [ ! -f /etc/ssh/keys/ssh_host_rsa_key ] && ssh-keygen -A && mv /etc/ssh/ssh_host* /etc/ssh/keys/; mkdir -p "/home/${USERNAME}/.ssh" && echo "$AUTHORIZED_KEY" > "/home/${USERNAME}/.ssh/authorized_keys"; chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.ssh"; chmod 0755 "/home/${USERNAME}/.ssh"; chmod 0700 "/home/${USERNAME}/.ssh/authorized_keys"; /bin/sshd -D -e

FROM sshd-sudo-workstation as d.rymcg.tech
ARG EXTRA_PACKAGES=
ARG USERNAME
ARG EMACS_CONFIG_REPO
ARG EMACS_CONFIG_BRANCH
RUN test -n "${EXTRA_PACKAGES}" && pacman -S --noconfirm --disable-download-timeout ${EXTRA_PACKAGES} || echo "No extra packages to install"
USER ${USERNAME}
RUN git clone "${EMACS_CONFIG_REPO}" \
    ~/git/vendor/enigmacurry/emacs && \
    git -C ~/git/vendor/enigmacurry/emacs checkout "${EMACS_CONFIG_BRANCH}" && \
    mkdir ~/.emacs.d && \
    ls -1 ~/git/vendor/enigmacurry/emacs/*.el | xargs -iXX ln -s XX ~/.emacs.d && \
    mkdir ~/.emacs.d/straight && \
    ln -s ~/git/vendor/enigmacurry/emacs/straight-versions ~/.emacs.d/straight/versions && \
    chown -R "${USERNAME}:${USERNAME}" ~
RUN yes | emacs --batch --load ~/.emacs.d/init.el

USER root
VOLUME /home/${USERNAME}

