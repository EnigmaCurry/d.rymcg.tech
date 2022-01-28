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

ALL_CONTAINERS = $(shell ${DOCKER} ps -a --filter "label=${LABEL}" -q)

.PHONY: network # Make the docker network (named ${NETWORK})
network:
	${DOCKER} network create ${NETWORK}

.PHONY: list # List all shell containers
list:
	${DOCKER} ps -a --filter "label=${LABEL}"

.PHONY: start # Start the shell container (named ${NAME})
start:
	@if [[ ${SYSTEMD} == true ]]; then make start-systemd | grep -v -E "make\[1\]\: (Entering|Leaving) directory"; else make start-shell | grep -v -E "make\[1\]\: (Entering|Leaving) directory"; fi

.PHONY: start-shell
start-shell:
	${DOCKER} start ${NAME} 2>/dev/null || ${DOCKER} run -d --name ${NAME} --hostname ${NAME} --network ${NETWORK} -v ${SHARED_VOLUME}:${SHARED_MOUNT} --label="${LABEL}" $(shell if [[ ${SYSBOX} == true ]]; then echo "--runtime=sysbox-runc"; fi) ${IMAGE} /bin/sh -c "while true; do sleep 10; done"

.PHONY: start-systemd
start-systemd:
	${DOCKER} start ${NAME} 2>/dev/null || ${DOCKER} run -d --name ${NAME} --hostname ${NAME} --network ${NETWORK} -v ${SHARED_VOLUME}:${SHARED_MOUNT} --label="${LABEL}" --user=root --entrypoint="/sbin/init" $(shell if [[ ${SYSBOX} == true ]]; then echo "--runtime=sysbox-runc"; fi) ${IMAGE}

.PHONY: stop # Stop the shell container (named ${NAME})
stop:
	${DOCKER} stop ${NAME}

.PHONY: stop-all # Stop all the shell containers
stop-all:
	${DOCKER} stop ${ALL_CONTAINERS}

.PHONY: shell # Connect to the shell container (named ${NAME})
shell: start
	${DOCKER} exec -it --user=${USERNAME} ${NAME} /bin/sh -c "if test -f /bin/bash; then /bin/bash; else /bin/sh; fi"

.PHONY: rm
rm: destroy

.PHONY: destroy # Destroy the shell container (named ${NAME})
destroy:
	@${BIN}/confirm no "This will destroy the \"${NAME}\" container and all its data"
	${DOCKER} rm -f ${NAME}

.PHONY: prune # Prune all the stopped shell containers
prune:
	@${BIN}/confirm no "This will destroy all the stopped shell containers"
	${DOCKER} container prune -f --filter "label=${LABEL}"

.PHONY: destroy-all # Destroy all the shell containers
destroy-all:
	@if [[ -z "${ALL_CONTAINERS}" ]]; then echo "No containers to destroy"; else ${BIN}/confirm no "This will destroy all the running and stopped shell containers" && ${DOCKER} rm -f ${ALL_CONTAINERS} &&	make status; fi

.PHONY: status
status: list

.PHONY: build # Build container images
build:
	ls images/Dockerfile.* | grep -o -P 'images/Dockerfile\.\K.*' | xargs -iXX ${DOCKER} build -t ${IMAGE_PREFIX}/XX --build-arg=USERNAME=XX -f images/Dockerfile.XX .

