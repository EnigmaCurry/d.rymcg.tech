INSTANCE ?= nix-docker-user
IMAGE ?= localhost/${INSTANCE}
BIN ?= ../../_scripts
GIT_SRC_VOLUME ?= nix_${INSTANCE}_private_git

.PHONY: help # Show this help screen
help:
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20

.PHONY: build # build docker image
build:
	docker build -t ${IMAGE} ${CURDIR}

.PHONY: create # Create the container (but don't start it)
create:
	@docker inspect ${INSTANCE} >/dev/null 2>/dev/null && echo "Container already exists: ${INSTANCE}" || (docker create --hostname ${INSTANCE} --name ${INSTANCE} -v ${GIT_SRC_VOLUME}:/root/git ${IMAGE} /bin/sh -c "while true; do sleep 3; done;" && echo "Created.")

.PHONY: start # start the container in the background
start: create
	@RUNNING="$$(docker inspect ${INSTANCE} 2>/dev/null | jq '.[0].State.Running')"; if [[ "$${RUNNING}" == "false" ]]; then docker start ${INSTANCE}; echo "Started."; elif [[ "$${RUNNING}" == "true" ]]; then echo "Already running."; else echo "Docker container doesn't exist: ${INSTANCE}."; exit 1; fi

.PHONY: install
install: build
	@CONTAINER_IMAGE="$$(docker inspect ${INSTANCE} | jq '.[0].Image')"; BUILD_IMAGE="docker image inspect localhost/nix-docker-user:latest | jq '.[0].Id'"; if [[ "$${CONTAINER_IMAGE}" != "$${BUILD_IMAGE}" ]]; then make --no-print-directory uninstall start; else make --no-print-directory start; fi

.PHONY: restart # restart the container in the background
restart: stop start

.PHONY: stop # stop the container
stop:
	docker stop ${INSTANCE}
	@echo "Stopped."

.PHONY: uninstall # remote the container, but keep the git volume
uninstall:
	docker rm -f ${INSTANCE};

.PHONY: destroy # destroy the container and ALL data in git volume
destroy: uninstall
	docker volume rm ${GIT_SRC_VOLUME}

.PHONY: shell # start a new interactive shell inside the container
shell: start
	@echo ""
	@echo "## Entering container: ${INSTANCE}"
	docker exec -it ${INSTANCE} bash

.PHONY: status
status:
	@docker inspect ${INSTANCE} >/dev/null 2>/dev/null && docker ps -a --filter name=${INSTANCE} || echo "Docker container doesn't exist: ${INSTANCE}."

.PHONY: ssh-copy-id
ssh-copy-id:
	@${BIN}/confirm yes "Do you want to overrwite the container's authorized_keys with your local ssh-agent's keyset" "?" && ssh-add -L | docker exec -i nix-docker-user sh -c "mkdir -p ~/.ssh; cat > ~/.ssh/authorized_keys; echo ''; echo 'Copied the following public keys:'; echo ''; cat ~/.ssh/authorized_keys; echo "
