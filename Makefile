ROOT_DIR = .

.PHONY: help # Display this help screen
help:
	@echo "Main Makefile help:"
	@grep -h '^.PHONY: .* #' Makefile ${ROOT_DIR}/_scripts/Makefile.globals | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t31

include _scripts/Makefile.globals
include _scripts/Makefile.cd

.PHONY: check-deps # Check dependencies
check-deps:
	_scripts/check_deps docker sed awk xargs openssl htpasswd jq curl sponge inotifywait git envsubst xdg-open sshfs wg

.PHONY: check-docker # Check if Docker is running
check-docker:
	@docker info >/dev/null && echo "Docker is running." || (echo "Could not connect to Docker!" && false)

.PHONY: config # Configure main variables
config: script-wizard check-deps check-docker check-dist-vars
#	@${BIN}/userns-remap check
	@echo ""
	@${BIN}/confirm yes "This will make a configuration for the current docker context (${DOCKER_CONTEXT})"
	@${BIN}/reconfigure_ask ${ROOT_ENV} ROOT_DOMAIN "Enter the root domain for this context"
	@echo "Configured ${ROOT_ENV}"
	@echo "ENV_FILE=${ENV_FILE}"
	@echo
	@${BIN}/confirm $$([[ "$$(${BIN}/dotenv -f ${ROOT_ENV} get DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL)"  == "true" ]] && echo yes || echo no) "Is this server behind another trusted proxy using the proxy protocol" "?" && ${BIN}/reconfigure ${ROOT_ENV} DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL=true DEFAULT_CLI_ROUTE_LAYER_4_PROXY_PROTOCOL=true || ${BIN}/reconfigure ${ROOT_ENV} DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL=false DEFAULT_CLI_ROUTE_LAYER_4_PROXY_PROTOCOL=false
	@echo
	@${BIN}/confirm $$([[ "$$(${BIN}/dotenv -f ${ROOT_ENV} get DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON)"  == "true" ]] && echo yes || echo no) "Do you want to save cleartext passwords in passwords.json by default" "?" && ${BIN}/reconfigure ${ROOT_ENV} DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON=true || ${BIN}/reconfigure ${ROOT_ENV} DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON=false
	@[[ -n "${USERNAME}" ]] && echo && echo "WARNING: the USERNAME variable is already set in your environment. This configuration is non-standard (Bash should use the USER variable instead). Having USERNAME set by default will interfere with the 'make shell' command. Some distros (eg. Fedora) set USERNAME by default. You must unset this variable before using the 'make shell' target. You can unset this variable in your ~/.bashrc file by adding the line: 'unset USERNAME'" | fold -s && echo || true

.PHONY: build # Build all container images
build:
	find ./ | grep docker-compose.yaml$ | xargs dirname | xargs -iXX docker-compose --env-file=XX/${ENV_FILE} -f XX/docker-compose.yaml build

.PHONY: open # Open the repository website README
open: readme

.PHONY: status # Check the status of all sub-projects
status:
	@docker compose ls | sed "s!$${PWD}!.!g"

.PHONY: backup-env # Create an encrypted backup of the .env files
backup-env:
	@ROOT_DIR=${ROOT_DIR} ${BIN}/backup_env

.PHONY: restore-env # Restore .env files from the encrypted backup
restore-env:
	@ROOT_DIR=${ROOT_DIR} ${BIN}/restore_env

.PHONY: delete-env # Delete all .env files
delete-env:
	@${BIN}/confirm no "This will find and delete ALL of the .env files recursively"
	@find ${ROOT_DIR} | grep -E '\.env$$|\.env_.*' && find ${ROOT_DIR} | grep -E '\.env$$|\.env_.*' | xargs shred -u || true
	@echo "Done."

.PHONY: delete-passwords # Delete all passwords.json files
delete-passwords:
	@${BIN}/confirm no "This will find and delete ALL of the passwords.json files recursively"
	@find ${ROOT_DIR} | grep -E 'passwords.*.json$$' && find ${ROOT_DIR} | grep -E 'passwords.*.json$$' | xargs shred -u  || true
	@echo "Done."

.PHONY: clean # Remove all private files (.env and passwords.json files)
clean: delete-env delete-passwords

.PHONY: show-ports # Show open ports on the Docker server
show-ports:
	@echo "Found these containers with open ports:"
	@docker ps --format '{{ .Names }}\t{{ .Ports }}' | grep ":"
#docker ps --format '{{ .ID }}' | xargs -iXX sh -c "docker inspect XX | jq -c '.[0].NetworkSettings.Ports' | grep '\[' >/dev/null && echo XX" | xargs -iXX sh -c "docker inspect XX | jq -cj '.[0].Name | @sh' && docker inspect XX | jq -c ' .[0].NetworkSettings.Ports[$i]' | jq -cr '.[].HostPort | @sh' | sed -z -e 's/\n//g' 2>&1 && echo" | sed -e "s/'/ /g" -e 's/ *$//g'
	@echo "Found these containers using the host network (so they could be publishing any port):"
	@docker ps --format '{{ .ID }}' | xargs -iXX sh -c "docker inspect XX | jq -cr '.[0].NetworkSettings.Networks | keys[]' | grep '^host$$'>/dev/null && docker inspect XX | jq -cr '.[0].Name'" | sed 's!/!!g'

.PHONY: audit # Audit container permissions and capabilities
audit:
	@(echo -e "CONTAINER\tUSER\tCAP_ADD\tCAP_DROP\tSEC_OPT\tBIND_MOUNTS\tPORTS" && docker ps --format "{{ .ID }}" | xargs -iXX sh -c "docker inspect XX | jq -r '.[0] | \"\(.Name)\t\(.Config.User | @sh)\t\(.HostConfig.CapAdd)\t\(.HostConfig.CapDrop)\t\(.HostConfig.SecurityOpt)\t\(.HostConfig.Binds)\t\(.HostConfig.PortBindings)\"'" | sed -e 's/^\///g' -e "s/''/root/g" -e "s/'//g" | sort) | column -t | sed -e 's/null/ __ /g' -e 's/^ *//' -e 's/ *$$//'

.PHONY: netstat # Show the host's netstat report
netstat:
	ssh $$(docker context inspect $$(${BIN}/docker_context) --format "{{ .Endpoints.docker.Host }}") netstat -plunt

.PHONY: userns-remap # Configure the Docker server for User Namespace Remap
userns-remap:
	@${BIN}/userns-remap true

.PHONY: userns-remap-off # Configure the Docker server for Root Namespace
userns-remap-off:
	@${BIN}/userns-remap false

.PHONY: userns-remap-check # Check the current Docker User Namespace Remap setting
userns-remap-check:
	@${BIN}/userns-remap check

.PHONY: readme # Open the README.md in your web browser
readme:
	xdg-open "https://github.com/EnigmaCurry/d.rymcg.tech/tree/master#readme"

.PHONY: install-cli # Install CLI
install-cli:
	@echo "## Add this to the bottom of your ~/.bashrc or ~/.profile ::"
	@echo ""
	@echo "## d.rymcg.tech"
	@echo "export PATH=\"$(realpath ${ROOT_DIR})/_scripts/user:\$${PATH}\""
	@echo "## optional TAB completion:"
	@echo "eval \$$(d.rymcg.tech completion bash)"
	@echo "complete -F __d.rymcg.tech_completions d.rymcg.tech"
	@echo "## If you make an alias to the d.rymcg.tech (eg. 'dry'),"
	@echo "## then you can make completion support for the alias too:"
	@echo "#complete -F __d.rymcg.tech_completions dry"
	@echo ""

.PHONY: docker-workstation # Build and run Docker workstation
docker-workstation:
	docker compose -f compose-dev.yaml build
	docker compose -f compose-dev.yaml run --rm -it -e INSTANCE=${INSTANCE} workstation /bin/bash

.PHONY: docker-workstation-clean # Clean up Docker workstation
docker-workstation-clean:
	docker compose -f compose-dev.yaml kill
	docker compose -f compose-dev.yaml down -v

.PHONY: install # Install a new sub-project with Docker
install:
	ENV_FILE=${ENV_FILE} ROOT_ENV=${ROOT_ENV} DOCKER_CONTEXT=${DOCKER_CONTEXT} ROOT_DIR=${ROOT_DIR} CONTEXT_INSTANCE=${CONTEXT_INSTANCE} ${BIN}/install

.PHONY: networks # List Docker networks
networks:
	@docker_networks=$$(docker network ls --format '{{.Name}}' | grep -vE '^(host|none|bridge)$$'); \
	(printf "%-35s %-20s %-10s %-10s %-20s\n" "Network Name" "CIDR" "Driver" "Scope" "Gateway"; \
	echo "------------------------------------------------------------------------------------------------"; \
	for network in $$docker_networks; do \
	  cidr=$$(docker network inspect $$network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'); \
	  driver=$$(docker network inspect $$network --format '{{.Driver}}'); \
	  scope=$$(docker network inspect $$network --format '{{.Scope}}'); \
	  gateway=$$(docker network inspect $$network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'); \
	  printf "%-35s %-20s %-10s %-10s %-20s\n" $$network $$cidr $$driver $$scope $$gateway; \
	done) | less -FSX

.PHONY: fail2ban # Configure fail2ban on this Docker host.
fail2ban:
	ENV_FILE=${ENV_FILE} ROOT_ENV=${ROOT_ENV} DOCKER_CONTEXT=${DOCKER_CONTEXT} ROOT_DIR=${ROOT_DIR} CONTEXT_INSTANCE=${CONTEXT_INSTANCE} ${BIN}/fail2ban

.PHONY: reconfigure # reconfigure a single environment variable (reconfigure var=THING=VALUE)
reconfigure:
	@[[ -n "$${var}" ]] || (echo -e "Error: Invalid argument, must set var.\n## Use: make reconfigure var=VAR_NAME=VALUE" && false)
	@${BIN}/reconfigure ${ROOT_ENV} "$${var%%=*}=$${var#*=}"
