ROOT_DIR = .

.PHONY: help # Show this help screen
help:
	@echo "Main Makefile help :"
	@grep -h '^.PHONY: .* #' Makefile ${ROOT_DIR}/_scripts/Makefile.globals | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20

include _scripts/Makefile.globals

.PHONY: check-deps
check-deps:
	_scripts/check_deps docker sed awk xargs openssl htpasswd jq

.PHONY: check-docker
check-docker:
	@docker info >/dev/null && echo "Docker is running." || (echo "Could not connect to Docker!" && false)

.PHONY: config # Configure main variables
config: check-deps check-docker
	@echo ""
	@${BIN}/confirm yes "This will make a configuration for the current docker context (${DOCKER_CONTEXT})"
	@${BIN}/reconfigure_ask ${ROOT_ENV} ROOT_DOMAIN "Enter the root domain for this context"
	@echo "Configured ${ROOT_ENV}"

.PHONY: build # build all container images
build:
	find ./ | grep docker-compose.yaml$ | xargs dirname | xargs -iXX docker-compose --env-file=XX/${ENV_FILE} -f XX/docker-compose.yaml build

.PHONY: open # Open the repository website README
open:
	xdg-open https://github.com/enigmacurry/d.rymcg.tech#readme

.PHONY: status # Check status of all sub-projects
status:
	docker compose ls

.PHONY: backup-env # Make an encrypted backup of the .env files
backup-env:
	@ROOT_DIR=${ROOT_DIR} ${BIN}/backup_env

.PHONY: restore-env # Restore .env files from encrypted backup
restore-env:
	@ROOT_DIR=${ROOT_DIR} ${BIN}/restore_env

.PHONY: delete-env
delete-env:
	@${BIN}/confirm no "This will find and delete ALL of the .env files recursively"
	@find ${ROOT_DIR} | grep -E '\.env$$|\.env_.*' && find ${ROOT_DIR} | grep -E '\.env$$|\.env_.*' | xargs shred -u || true
	@echo "Done."

.PHONY: delete-passwords
delete-passwords:
	@${BIN}/confirm no "This will find and delete ALL of the passwords.json files recursively"
	@find ${ROOT_DIR} | grep -E 'passwords.*.json$$' && find ${ROOT_DIR} | grep -E 'passwords.*.json$$' | xargs shred -u  || true
	@echo "Done."

.PHONY: clean # Remove all private files (.env and passwords.json files)
clean: delete-env delete-passwords

.PHONY: show-ports # Show open ports on the docker server
show-ports:
	@echo "Found these containers with open ports:"
	@docker ps --format '{{ .Names }}\t{{ .Ports }}' | grep ":"
#docker ps --format '{{ .ID }}' | xargs -iXX sh -c "docker inspect XX | jq -c '.[0].NetworkSettings.Ports' | grep '\[' >/dev/null && echo XX" | xargs -iXX sh -c "docker inspect XX | jq -cj '.[0].Name | @sh' && docker inspect XX | jq -c ' .[0].NetworkSettings.Ports[$i]' | jq -cr '.[].HostPort | @sh' | sed -z -e 's/\n//g' 2>&1 && echo" | sed -e "s/'/ /g" -e 's/ *$//g'
	@echo "Found these containers using the host network (so they could be publishing any port):"
	@docker ps --format '{{ .ID }}' | xargs -iXX sh -c "docker inspect XX | jq -cr '.[0].NetworkSettings.Networks | keys[]' | grep '^host$$'>/dev/null && docker inspect XX | jq -cr '.[0].Name'" | sed 's!/!!g'

.PHONY: show-users # Show container users and capabilities
show-users:
	@(echo -e "NAME\tUSER\tCAP_ADD\tCAP_DROP" && docker ps --format "{{ .ID }}" | xargs -iXX sh -c "docker inspect XX | jq -r '.[0] | \"\(.Name)\t\(.Config.User | @sh)\t\(.HostConfig.CapAdd)\t\(.HostConfig.CapDrop)\"'" | sed -e 's/^\///g' -e "s/''/root/g" -e "s/'//g") | column -t
