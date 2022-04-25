#############################################
### Default variables (can be overriden by environment or hardcoded here):
#############################################
DISTRO ?= bullseye
VMNAME ?= docker-vm
DISTRO ?= bullseye
DISK ?= 30G
MEMORY ?= 4096
DOMAIN ?= localdomain
MAC ?= 52:54:98:76:54:32
TIMEZONE ?= Etc/UTC
SSH_PORT ?= 2221
EXTRA_PORTS ?= 8000:80,8443:443,5432:5432
LOCALE ?= en_US
DEBIAN_MIRROR ?= mirrors.xmission.com
VMROOT ?= VMs

## Make HOSTFWD_HOST='*' if you want all hosts to be able to connect:
HOSTFWD_HOST ?= 127.0.0.1

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

.PHONY: up # Build and boot Docker VM
up: build-and-boot

.PHONY: help # Show this help screen
help:
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t22

.PHONY: down
down:
	./shutdown.sh
	@sleep 2
	systemctl --user status ${VMNAME} --no-pager; true

.PHONY: install # Install systemd units for Docker VM service
install:
	./systemd_install.sh

.PHONY: install-public # Install systemd units for PUBLIC Docker VM service
install-public:
	HOSTFWD_HOST='*' ./systemd_install.sh

.PHONY: enable # Enable systemd service on boot and start Docker VM now
enable:
	systemctl --user enable --now ${VMNAME}
	sleep 2
	systemctl --user status ${VMNAME} --no-pager; true

.PHONY: start # Start systemd service now
start:
	systemctl --user start ${VMNAME}
	sleep 2
	systemctl --user status ${VMNAME} --no-pager; true

.PHONY: disable # Disable systemd service on boot and stop Docker VM now
disable:
	systemctl --user disable --now ${VMNAME}
	sleep 2
	systemctl --user status ${VMNAME} --no-pager; true

.PHONY: stop # stop systemd service now
stop:
	systemctl --user stop ${VMNAME}
	sleep 2
	systemctl --user status ${VMNAME} --no-pager; true

.PHONY: status # show status of systemd service
status:
	systemctl --user status ${VMNAME} --no-pager ; true

.PHONY: logs # show kernel logs
logs:
	journalctl --user --unit ${VMNAME} --no-pager

.PHONY: check-name
check-name:
	$(call check_defined, VMNAME)

.PHONY: clean
clean: check-name
	rm -rf ${VMROOT}/${VMNAME}.qcow ${VMROOT}/${VMNAME}-root-pass.txt build.* ${VMROOT}/${VMNAME}-installer.log

.PHONY: build
build: check-name
	DISTRO=${DISTRO} \
	DISK=${DISK} \
	VMNAME=${VMNAME} \
	DOMAIN=${DOMAIN} \
	LOCALE=${LOCALE} \
	DEBIAN_MIRROR=${DEBIAN_MIRROR} \
	TIMEZONE=${TIMEZONE} \
  MAC=${MAC} \
	./build_qemu_debian_image.sh

.PHONY: build-and-boot
build-and-boot: check-name build
	VMNAME=${VMNAME} \
	SSH_PORT=${SSH_PORT} \
	./create_ssh_config.sh

	VMNAME=${VMNAME} \
	SSH_PORT=${SSH_PORT} \
	MEMORY=${MEMORY} \
	DOMAIN=${DOMAIN} \
  MAC=${MAC} \
	EXTRA_PORTS=${EXTRA_PORTS} \
	HOSTFWD_HOST=${HOSTFWD_HOST} \
	./boot.sh

