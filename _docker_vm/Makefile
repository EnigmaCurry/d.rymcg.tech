## boilerplate help target. Keep this as the first target to make it the default one.
## All .PHONY targets will now be self-documenting via posterior comments.
.PHONY: help # Show this help screen
help:
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20

#############################################
### Default variables:
#############################################
VMROOT ?= VMs
DISK ?= 25G
MEMORY ?= 4096
TIMEZONE ?= Etc/UTC
SSH_PORT ?= 10022
DISTRO ?= bullseye

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

#############################################
### Core targets:
#############################################
.PHONY: check-name
check-name:
	$(call check_defined, VMNAME)

.PHONY: clean
clean: check-name
	rm -rf ${VMROOT}/${VMNAME}.qcow ${VMROOT}/${VMNAME}-root-pass.txt build.* ${VMROOT}/${VMNAME}-installer.log

.PHONY: build
build: check-name
	./build_qemu_debian_image.sh

.PHONY: build-and-boot
build-and-boot: check-name build
	./create_ssh_config.sh
	./boot.sh

#############################################
### Example VM targets
### (customize to your liking)
#############################################

.PHONY: docker-vm # Build Docker VM
docker-vm:
	VMNAME=docker-vm \
	DISTRO=bullseye \
	DISK=30G \
	MEMORY=4096 \
	SSH_PORT=2221 \
	TIMEZONE=Etc/UTC \
	EXTRA_PORTS=8000:80,8443:443,5432:5432 \
	DEBIAN_MIRROR=mirrors.xmission.com \
	make --no-print-directory build-and-boot
	sleep 10
	VMNAME=docker-vm ./install_docker.sh

.PHONY: docker-vm-clean
docker-vm-clean:
	make --no-print-directory clean VMNAME=docker-vm

.PHONY: my-buster # Build buster VM
my-buster:
	VMNAME=my-buster \
	DISTRO=buster \
	DISK=30G \
	MEMORY=2048 \
	SSH_PORT=2223 \
	TIMEZONE=America/Los_Angeles \
  make --no-print-directory build-and-boot

.PHONY: my-buster-clean
my-buster-clean:
	make --no-print-directory clean VMNAME=my-buster

.PHONY: my-bullseye # Build bullseye VM
my-bullseye:
	VMNAME=my-bullseye \
	DISTRO=bullseye \
	DISK=30G \
	MEMORY=2048 \
	SSH_PORT=2224 \
	TIMEZONE=America/Los_Angeles \
  make --no-print-directory build-and-boot

.PHONY: my-bullseye-clean
my-bullseye-clean:
	make --no-print-directory clean VMNAME=my-bullseye
