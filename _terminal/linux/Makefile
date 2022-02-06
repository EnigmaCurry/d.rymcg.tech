ROOT_DIR = ../..
include ../../_scripts/Makefile.help-basic
include ../../_scripts/Makefile.globals

# Switch to podman by setting DOCKER=podman environment variable
DOCKER ?= docker
TEMPLATE ?= arch
SYSTEMD ?= false
SYSBOX ?= false
IMAGE_PREFIX ?= localhost/shell-container
NAME ?= ${TEMPLATE}
IMAGE ?= ${IMAGE_PREFIX}/${TEMPLATE}
NETWORK ?= shell-lan
LABEL = shell-linux-container
SHARED_VOLUME ?= shell-shared
SHARED_MOUNT ?= /shared
USERNAME ?= root
SUDO ?= false
WORKDIR ?= /
ENTRYPOINT ?= /bin/bash
COMMAND ?= /bin/sh -c 'if test -f ${ENTRYPOINT}; then ${ENTRYPOINT}; else /bin/sh; fi'
DOCKERFILE ?= Dockerfile
BUILDSRC ?= images/${TEMPLATE}
DOCKER_ARGS ?=
BUILD_ARGS ?= --build-arg FROM

.PHONY: network # Make the docker network (named ${NETWORK})
network:
	${DOCKER} network create ${NETWORK} || true

.PHONY: list # List all shell containers of the given TEMPLATE
list:
	${DOCKER} ps -a --filter "label=${LABEL}.template=${TEMPLATE}"

.PHONY: run # Run command directly (don't start shell server)
run:
	${DOCKER} run --rm -it --hostname ${NAME} --network ${NETWORK} -v ${SHARED_VOLUME}:${SHARED_MOUNT} --label="${LABEL}.template=${TEMPLATE}" $(shell if [[ ${SYSBOX} == true ]]; then echo "--runtime=sysbox-runc"; fi) ${DOCKER_ARGS} ${IMAGE} ${COMMAND}

.PHONY: start # Start the shell container (named ${NAME})
start:
	@if [[ ${SYSTEMD} == true ]]; then make start-systemd | grep -v -E "make\[1\]\: (Entering|Leaving) directory"; else make start-shell | grep -v -E "make\[1\]\: (Entering|Leaving) directory"; fi

.PHONY: start-shell
start-shell:
	${DOCKER} start ${NAME} 2>/dev/null || ${DOCKER} run -d --name ${NAME} --hostname ${NAME} --network ${NETWORK} -v ${SHARED_VOLUME}:${SHARED_MOUNT} --label="${LABEL}.template=${TEMPLATE}" $(shell if [[ ${SYSBOX} == true ]]; then echo "--runtime=sysbox-runc"; fi) ${DOCKER_ARGS} ${IMAGE} /bin/sh -c "while true; do sleep 10; done"

.PHONY: start-systemd
start-systemd:
	${DOCKER} start ${NAME} 2>/dev/null || ${DOCKER} run -d --name ${NAME} --hostname ${NAME} --network ${NETWORK} -v ${SHARED_VOLUME}:${SHARED_MOUNT} --label="${LABEL}.template=${TEMPLATE}" --user=root --entrypoint="/sbin/init" $(shell if [[ ${SYSBOX} == true ]]; then echo "--runtime=sysbox-runc"; fi) ${DOCKER_ARGS} ${IMAGE}

.PHONY: stop # Stop the shell container (named ${NAME})
stop:
	${DOCKER} kill ${NAME}

.PHONY: start-all # Start all the shell containers of the given TEMPLATE
start-all:
	${DOCKER} start $(shell ${DOCKER} ps -a --filter "label=${LABEL}.template=${TEMPLATE}" -q)

.PHONY: stop-all # Stop all the shell containers of the given TEMPLATE
stop-all:
	${DOCKER} kill $(shell ${DOCKER} ps -a --filter "label=${LABEL}.template=${TEMPLATE}" -q)

.PHONY: shell # Connect to the shell container (named ${NAME})
shell: start
	${DOCKER} exec -it --user=${USERNAME} --workdir=${WORKDIR} ${NAME} ${COMMAND}

.PHONY: rm
rm: destroy

.PHONY: destroy # Destroy the shell container (named ${NAME})
destroy:
	@${BIN}/confirm no "This will destroy the \"${NAME}\" container and all its data"
	@${DOCKER} kill ${NAME} 2>&1 > /dev/null
	@${DOCKER} rm -f ${NAME} 2>&1 > /dev/null

.PHONY: prune # Prune all the stopped shell containers
prune:
	@${BIN}/confirm no "This will destroy all *stopped* shell containers of the template \"${TEMPLATE}\""
	${DOCKER} container prune -f --filter "label=${LABEL}.template=${TEMPLATE}"

.PHONY: destroy-all # Destroy all the shell containers of the given TEMPLATE
destroy-all:
	@${BIN}/confirm no "This will destroy all the shell containers of the template \"${TEMPLATE}\""
	${DOCKER} rm -f $(shell ${DOCKER} ps -a --filter "label=${LABEL}.template=${TEMPLATE}" -q) && make --no-print-directory status

.PHONY: status
status: list

.PHONY: build # Build template image
build:
	if [ -d ${BUILDSRC} ]; then \
		cd ${BUILDSRC} && ${DOCKER} build ${BUILD_ARGS} -t ${IMAGE_PREFIX}/${TEMPLATE} -f ${DOCKERFILE} .; \
	else \
		${DOCKER} build ${BUILD_ARGS} -t ${IMAGE_PREFIX}/${TEMPLATE} -f ${DOCKERFILE} ${BUILDSRC}; \
	fi
	@echo "Build complete. You must create new containers to use the new image."

.PHONY: create_user # Create a user inside a container with sudo privileges (unless SUDO=false)
create_user:
	${DOCKER} exec --user=root ${NAME} /bin/sh -c "useradd -m ${USERNAME} || true"
	@if [[ "${SUDO}" == "true" ]]; then ${DOCKER} exec --user=root ${NAME} /bin/sh -c "groupadd wheel; gpasswd -a ${USERNAME} wheel"; fi

.PHONY: sigusr1 # Send SIGUSR1 to the container
sigusr1:
	${DOCKER} kill --signal SIGUSR1 ${NAME}

.PHONY: sigusr2 # Send SIGUSR2 to the container
sigusr2:
	${DOCKER} kill --signal SIGUSR2 ${NAME}

