ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} TOR_INSTANCE=$${instance:-default}

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:tor instance=@TOR_INSTANCE hidden_services=TOR_HIDDEN_SERVICES onion_hosts=TOR_ONION_HOSTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=tor

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: install-hook
install-hook:
	@echo
	@echo "Tor hidden services are starting. Wait for bootstrap to complete, then run:"
	@echo "  make onion-addresses"
	@echo
	@echo "This will update TOR_ONION_HOSTS in the .env file."
	@echo "Then run 'make reinstall' to enable Traefik routing."

.PHONY: list-services # List configured hidden services
list-services:
	@./list_hidden_services.py ${ENV_FILE}

.PHONY: add-hidden-service # Add a hidden service (without replacing existing ones)
add-hidden-service:
	@test -n "$(svc)" || (echo "Usage: make add-hidden-service svc='[\"name\",\"docker-service\"]'" && echo "       make add-hidden-service svc='[\"name\",tor_port,traefik_port]'" && false)
	@./add_hidden_service.py ${ENV_FILE} '$(svc)'

.PHONY: onion-addresses # Read .onion addresses and update TOR_ONION_HOSTS in .env
onion-addresses:
	@docker exec ${PROJECT_NAME}-tor-1 sh -c 'for dir in /var/lib/tor/*/; do name=$$(basename "$$dir"); [ -f "$$dir/hostname" ] && echo "$$name $$(cat "$$dir/hostname")"; done' | ./update_onion_hosts.py ${ENV_FILE}
