ROOT_DIR = .

.PHONY: help # Show this help screen
help:
	@echo "Main Makefile help :"
	@grep -h '^.PHONY: .* #' Makefile ${ROOT_DIR}/_scripts/Makefile.globals | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20

include _scripts/Makefile.globals

.PHONY: check-deps
check-deps:
	_scripts/check_deps docker docker-compose sed awk xargs openssl htpasswd jq

.PHONY: check-docker
check-docker:
	@docker info >/dev/null && echo "Docker is running." || (echo "Could not connect to Docker!" && false)

.PHONY: config # Configure main variables
config: check-deps check-docker
	@echo ""
	@ENV_FILE=".env.makefile" ENV_DIST_FILE=".env-dist.makefile" ${BIN}/reconfigure_ask ROOT_DOMAIN "Enter the default root domain for all your projects"

.PHONY: build # build all container images
build: build-traefik-htpasswd
	find ./ | grep docker-compose.yaml$ | xargs -iXX docker-compose -f XX build

.PHONY: open # Open the repository website README
open:
	xdg-open https://github.com/enigmacurry/d.rymcg.tech#readme

.PHONY: status # Check status of all sub-projects
status:
	docker-compose ls

.PHONY: backup-env # Make an encrypted backup of the .env files
backup-env:
	@ROOT_DIR=${ROOT_DIR} ${BIN}/backup_env

.PHONY: restore-env # Restore .env files from encrypted backup
restore-env:
	@ROOT_DIR=${ROOT_DIR} ${BIN}/restore_env

.PHONY: delete-env
delete-env:
	@${BIN}/confirm no "This will find and delete ALL of the .env files recursively"
	find ${ROOT_DIR} | grep -E '\.env$$' | xargs rm -f
	@echo "Done."

.PHONY: delete-passwords
delete-passwords:
	@${BIN}/confirm no "This will find and delete ALL of the passwords.json files recursively"
	find ${ROOT_DIR} | grep -E 'passwords.json$$' | xargs rm -f
	@echo "Done."

.PHONY: clean # Remove all private files (.env and passwords.json files)
clean: delete-env delete-passwords
