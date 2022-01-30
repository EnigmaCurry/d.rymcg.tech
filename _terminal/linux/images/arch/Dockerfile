FROM archlinux

RUN pacman -Syu --noconfirm && \
    pacman -S sudo git base-devel --noconfirm && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheelers && \
    systemctl mask \
       systemd-journald-audit.socket \
       systemd-udev-trigger.service \
       systemd-networkd-wait-online.service \
       systemd-firstboot.service && \
    systemctl set-default multi-user.target

