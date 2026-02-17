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
	@test -n "$(svc)" || (echo "Usage: d.rymcg.tech make tor add-service svc=name [host=HOSTNAME] [prefix=VANITY] [port=TOR:LOCAL]" && echo "  e.g. d.rymcg.tech make tor add-service svc=whoami host=whoami.example.com" && echo "       d.rymcg.tech make tor add-service svc=whoami host=whoami.example.com prefix=who" && echo "       d.rymcg.tech make tor add-service svc=whoami" && echo "       d.rymcg.tech make tor add-service svc=ssh port=22:22" && false)
	@./scripts/add_hidden_service.py ${ENV_FILE} '$(svc)' '$(port)' '$(prefix)' ${PROJECT_NAME} '$(host)'

.PHONY: backup # Export onion keys and env file to an encrypted archive
backup:
	@test -n "$(archive)" || (echo "Usage: d.rymcg.tech make tor backup archive=FILENAME.tar.gz.gpg" && false)
	@docker volume inspect ${PROJECT_NAME}_tor_data > /dev/null 2>&1 || (echo "Error: volume ${PROJECT_NAME}_tor_data does not exist" && false)
	@TMPDIR=$$(mktemp -d) && \
	  mkdir -p $$TMPDIR/keys && \
	  echo "Backing up volume: ${PROJECT_NAME}_tor_data" && \
	  docker run --rm -v ${PROJECT_NAME}_tor_data:/data:ro alpine tar cf - -C /data . | tar xf - -C $$TMPDIR/keys && \
	  echo "Backing up env file: ${ENV_FILE}" && \
	  cp ${ENV_FILE} $$TMPDIR/env && \
	  echo "Contents:" && \
	  find $$TMPDIR -type f | sed "s|^$$TMPDIR/||" | sed 's|^|  |' && \
	  tar cf - -C $$TMPDIR . | gzip | gpg --symmetric --cipher-algo AES256 --pinentry-mode loopback -o $(archive) && \
	  rm -rf $$TMPDIR
	@echo "Exported to $(archive)"

.PHONY: restore # Import onion keys and env file from an encrypted archive
restore:
	@test -n "$(archive)" || (echo "Usage: d.rymcg.tech make tor restore archive=FILENAME.tar.gz.gpg" && false)
	@test -f "$(archive)" || (echo "$(archive) not found" && false)
	@TMPDIR=$$(mktemp -d) && \
	  gpg --decrypt --pinentry-mode loopback $(archive) | tar xzf - -C $$TMPDIR && \
	  echo "Restoring keys to volume: ${PROJECT_NAME}_tor_data" && \
	  docker run --rm -v ${PROJECT_NAME}_tor_data:/data -v $$TMPDIR/keys:/restore:ro alpine sh -c 'cp -a /restore/. /data/' && \
	  echo "Restoring env file: ${ENV_FILE}" && \
	  cp $$TMPDIR/env ${ENV_FILE} && \
	  echo "Restored contents:" && \
	  find $$TMPDIR -type f | sed "s|^$$TMPDIR/||" | sed 's|^|  |' && \
	  rm -rf $$TMPDIR
	@echo "Run 'd.rymcg.tech make tor reinstall' to apply."

.PHONY: remove-service # Remove a hidden service by name
remove-service:
	@test -n "$(name)" || (echo "Usage: d.rymcg.tech make tor remove-service name=SERVICE_NAME" && false)
	@./scripts/remove_hidden_service.py ${ENV_FILE} '$(name)'

.PHONY: add-client # Create a client keypair for Tor v3 client authorization
add-client:
	@test -n "$(client)" || (echo "Usage: d.rymcg.tech make tor add-client client=NAME" && false)
	@./scripts/add_client.py ${PROJECT_NAME} '$(client)'

.PHONY: authorize-client # Grant a client access to a hidden service
authorize-client:
	@test -n "$(svc)" || (echo "Usage: d.rymcg.tech make tor authorize-client svc=SERVICE client=CLIENT" && false)
	@test -n "$(client)" || (echo "Usage: d.rymcg.tech make tor authorize-client svc=SERVICE client=CLIENT" && false)
	@./scripts/authorize_client.py ${PROJECT_NAME} '$(svc)' '$(client)'

.PHONY: show-credential # Display client credentials for Tor Browser
show-credential:
	@test -n "$(client)" || (echo "Usage: d.rymcg.tech make tor show-credential client=NAME" && false)
	@./scripts/show_credential.py ${PROJECT_NAME} '$(client)'

.PHONY: list-clients # List clients and their authorized services
list-clients:
	@./scripts/list_clients.py ${PROJECT_NAME} '$(svc)'

.PHONY: revoke-client # Remove a client's access to a hidden service
revoke-client:
	@test -n "$(svc)" || (echo "Usage: d.rymcg.tech make tor revoke-client svc=SERVICE client=CLIENT" && false)
	@test -n "$(client)" || (echo "Usage: d.rymcg.tech make tor revoke-client svc=SERVICE client=CLIENT" && false)
	@./scripts/revoke_client.py ${PROJECT_NAME} '$(svc)' '$(client)'

.PHONY: remove-client # Delete a client and revoke access to all services
remove-client:
	@test -n "$(client)" || (echo "Usage: d.rymcg.tech make tor remove-client client=NAME" && false)
	@./scripts/remove_client.py ${PROJECT_NAME} '$(client)'
