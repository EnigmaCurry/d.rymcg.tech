FROM debian:bullseye
ARG INSTALL_PACKAGES

RUN DEBIAN_FRONTEND=noninteractive apt -y update; \
    DEBIAN_FRONTEND=noninteractive apt -y install --no-install-recommends ${INSTALL_PACKAGES}; \
    echo "ReadKMsg=no" >> /etc/systemd/journald.conf; \
    systemctl mask \
       systemd-journald-audit.socket \
       systemd-udevd.service \
       systemd-udev-trigger.service \
       systemd-udevd-kernel.socket \
       systemd-udevd-control.socket \
       systemd-modules-load.service \
       sys-kernel-config.mount \
       sys-kernel-debug.mount \
       sys-kernel-tracing.mount;

### Cleanup
# RUN DEBIAN_FRONTEND=noninteractive apt-get clean -y; \
#     rm -rf \
#        /var/cache/debconf/* \
#        /var/lib/apt/lists/* \
#        /var/log/* \
#        /tmp/* \
#        /var/tmp/* \
#        /usr/share/doc/* \
#        /usr/share/man/* \
#        /usr/share/local/*;

VOLUME /etc
VOLUME /home
WORKDIR /root
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT [ "/sbin/init", "--log-level=info" ]
