ARG FROM=archlinux
FROM ${FROM}

RUN pacman -Syu --noconfirm && \
    pacman -S sudo git base-devel --noconfirm && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheelers

# Some archlinux images may not include systemd, so check for its existance first:
RUN test ! -f /usr/bin/systemctl || \
    ( \
    systemctl mask \
       systemd-journald-audit.socket \
       systemd-udev-trigger.service \
       systemd-networkd-wait-online.service \
       systemd-firstboot.service && \
    systemctl set-default multi-user.target \
    )
