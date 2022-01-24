ROOT_DIR = ../..
include ../../_scripts/Makefile.help-basic
include ../../_scripts/Makefile.globals

# Switch to podman by setting DOCKER=podman environment variable
DOCKER ?= docker
IMAGE ?= docker.io/archlinux
NAME ?= arch
NETWORK ?= shell-lan
LABEL = shell-linux-container
SHARED_VOLUME ?= shell-shared
SHARED_MOUNT ?= /shared

ALL_CONTAINERS = $(shell ${DOCKER} ps -a --filter "label=${LABEL}" -q)

.PHONY: network # Make the docker network (named ${NETWORK})
network:
	${DOCKER} network create ${NETWORK}

.PHONY: list # List all shell containers
list:
	${DOCKER} ps -a --filter "label=${LABEL}"

.PHONY: start # Start the shell container (named ${NAME})
start:
	${DOCKER} start ${NAME} 2>/dev/null || ${DOCKER} run --name ${NAME} --hostname ${NAME} --network ${NETWORK} -v ${SHARED_VOLUME}:${SHARED_MOUNT} -d --label="${LABEL}" ${IMAGE} /bin/sh -c "while true; do sleep 10; done"

.PHONY: stop # Stop the shell container (named ${NAME})
stop:
	${DOCKER} stop ${NAME}

.PHONY: stop-all # Stop all the shell containers
stop-all:
	${DOCKER} stop ${ALL_CONTAINERS}

.PHONY: shell # Connect to the shell container (named ${NAME})
shell: start
	${DOCKER} exec -it ${NAME} /bin/sh -c "if test -f /bin/bash; then /bin/bash; else /bin/sh; fi"

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
	@${BIN}/confirm no "This will destroy all the running and stopped shell containers"
	${DOCKER} rm -f ${ALL_CONTAINERS}
	make status

.PHONY: status
status: list

.PHONY: alpine # Create the Alpine singleton
alpine:
	IMAGE=docker.io/alpine NAME=alpine make shell

.PHONY: arch # Create the Arch singleton
arch:
	IMAGE=docker.io/archlinux NAME=arch make shell

.PHONY: busybox # Create the Busybox singleton
busybox:
	IMAGE=docker.io/busybox NAME=busybox make shell

.PHONY: python # Create the Python singleton
python:
	IMAGE=docker.io/python:3 NAME=python make shell

.PHONY: debian # Create the Debian singleton
debian:
	IMAGE=docker.io/debian:stable-slim NAME=debian make shell

.PHONY: fedora # Create the Fedora singleton
fedora:
	IMAGE=docker.io/fedora NAME=fedora make shell

.PHONY: ubuntu # Create the Ubuntu singleton
ubuntu:
	IMAGE=docker.io/ubuntu:20.04 NAME=ubuntu make shell

