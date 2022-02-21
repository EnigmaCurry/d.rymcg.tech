FROM docker.io/lsiobase/rdesktop-web:arch
ARG PROGRAMS
RUN pacman --noconfirm -Syu && \
    pacman -S --noconfirm xfce4 rxvt-unicode xorg-fonts-misc inetutils && \
    pacman -R --noconfirm xfce4-terminal
RUN pacman -S --noconfirm ${PROGRAMS}
