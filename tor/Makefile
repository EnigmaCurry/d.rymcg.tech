ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} TOR_INSTANCE=$${instance:-default}

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:tor instance=@TOR_INSTANCE

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
	@echo "  d.rymcg.tech make tor list-services"
	@echo
	@echo "Then configure each service with its .onion address as TRAEFIK_HOST."

.PHONY: list-services # List configured hidden services and .onion addresses
list-services:
	@docker exec ${PROJECT_NAME}-tor-1 sh -c 'for dir in /var/lib/tor/*/; do name=$$(basename "$$dir"); [ -f "$$dir/hostname" ] && echo "$$name $$(cat "$$dir/hostname")"; done' 2>/dev/null | ./scripts/list_hidden_services.py ${ENV_FILE}

.PHONY: add-service # Add a hidden service (without replacing existing ones)
add-service:
	@test -n "$(svc)" || (echo "Usage: d.rymcg.tech make tor add-service svc=name" && echo "  e.g. d.rymcg.tech make tor add-service svc=whoami" && echo "       d.rymcg.tech make tor add-service svc=name port=TOR_PORT:LOCAL_PORT" && echo "  e.g. d.rymcg.tech make tor add-service svc=ssh port=22:22" && false)
	@./scripts/add_hidden_service.py ${ENV_FILE} '$(svc)' '$(port)'

.PHONY: backup # Export onion keys to an encrypted archive
backup:
	@test -n "$(archive)" || (echo "Usage: d.rymcg.tech make tor backup archive=FILENAME.tar.gz.gpg" && false)
	@docker run --rm -v ${PROJECT_NAME}_tor_data:/data:ro alpine tar cf - -C /data . | gzip | gpg --symmetric --cipher-algo AES256 -o $(archive)
	@echo "Exported onion keys to $(archive)"

.PHONY: restore # Import onion keys from an encrypted archive
restore:
	@test -n "$(archive)" || (echo "Usage: d.rymcg.tech make tor restore archive=FILENAME.tar.gz.gpg" && false)
	@test -f "$(archive)" || (echo "$(archive) not found" && false)
	@gpg --decrypt $(archive) | docker run --rm -i -v ${PROJECT_NAME}_tor_data:/data alpine sh -c 'cd /data && tar xzf -'
	@echo "Restored onion keys from $(archive)"
	@echo "Run 'd.rymcg.tech make tor reinstall' to apply."

.PHONY: remove-service # Remove a hidden service by name
remove-service:
	@test -n "$(name)" || (echo "Usage: d.rymcg.tech make tor remove-service name=SERVICE_NAME" && false)
	@./scripts/remove_hidden_service.py ${ENV_FILE} '$(name)'
