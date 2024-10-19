FROM debian:bookworm

RUN DEBIAN_FRONTEND=noninteractive apt -y update && \
    DEBIAN_FRONTEND=noninteractive apt -y install --no-install-recommends \
    procps systemd systemd-sysv libsystemd0 ca-certificates iptables iproute2 \
    kmod locales sudo udev less wget curl git jq podman fuse-overlayfs

RUN ln -s /usr/bin/podman /usr/local/bin/docker && \
    echo "ReadKMsg=no" >> /etc/systemd/journald.conf && \
    printf 'unqualified-search-registries=["localhost:5000","docker.io"]\n\n[[registry]]\nlocation="localhost:5000"\ninsecure=true\n' \
      > /etc/containers/registries.conf.d/localhost.conf && \
    printf '[engine]\ncgroup_manager = "cgroupfs"\n' > /etc/containers/containers.conf && \
    systemctl mask \
       systemd-journald-audit.socket \
       systemd-udevd.service \
       systemd-udev-trigger.service \
       systemd-udevd-kernel.socket \
       systemd-udevd-control.socket \
       systemd-modules-load.service \
       sys-kernel-config.mount \
       sys-kernel-debug.mount \
       sys-kernel-tracing.mount

RUN git clone https://github.com/openfaas/faasd ~/git/vendor/openfaas/faasd

### Cleanup
RUN DEBIAN_FRONTEND=noninteractive apt-get clean -y; \
    rm -rf \
       /var/cache/debconf/* \
       /var/lib/apt/lists/* \
       /var/log/* \
       /tmp/* \
       /var/tmp/* \
       /usr/share/doc/* \
       /usr/share/man/* \
       /usr/share/local/*


VOLUME /etc
VOLUME /home
VOLUME /root
WORKDIR /root
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT [ "/sbin/init", "--log-level=info" ]
