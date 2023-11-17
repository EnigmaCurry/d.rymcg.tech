ROOT_DIR = ..
GRANT_MODE ?= ro

include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NTFY_TRAEFIK_HOST "Enter the ntfy domain name" ntfy.${ROOT_DOMAIN}
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} NTFY_IP_SOURCERANGE "Enter the nework subnet filter (eg. 0.0.0.0/0 to allow all; 192.168.1.1/32 to deny all but one address)" 0.0.0.0/0
	@echo ""
	@echo "Define the default access rules for unauthenticated users:"
	@echo "  read-write = complete public access to all unprotected channels"
	@echo "  read-only = public read only access to all unprotected channels"
	@echo "  write-only = public write only access to all unprotected channels"
	@echo "  deny-all = deny all unauthenticated users"
	@echo "write-only mode is recommended. write-only will require a configured password to receive notifications, but will let anyone send you them. Choose long unguessable channel names and treat them as preshared keys with your senders."
	@${BIN}/reconfigure_ask ${ENV_FILE} NTFY_AUTH_DEFAULT_ACCESS "Enter the default access rule" write-only

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=ntfy

.PHONY: user
user:
	@NTFY_PASSWORD=$$(openssl rand -base64 25) && read -e -p "Enter the username to create: " NTFY_USERNAME && docker compose --env-file=${ENV_FILE} exec -e NTFY_PASSWORD=$${NTFY_PASSWORD} ntfy ntfy user add $${NTFY_USERNAME} && echo "Username: $${NTFY_USERNAME}" && echo "Password: $${NTFY_PASSWORD}"

.PHONY: access
access:
	docker compose --env-file=${ENV_FILE} exec -it ntfy ntfy access

.PHONY: grant
grant:
	@read -e -p "Enter the username to grant: " NTFY_USERNAME && read -e -p "Enter the channel name: " NTFY_CHANNEL && docker compose --env-file=${ENV_FILE} exec -e NTFY_PASSWORD=$${NTFY_PASSWORD} ntfy ntfy access $${NTFY_USERNAME} $${NTFY_CHANNEL} $${GRANT_MODE:-ro}

.PHONY: grant-anonymous
grant-anonymous:
	@read -e -p "Enter the channel name: " NTFY_CHANNEL && docker compose --env-file=${ENV_FILE} exec -e NTFY_PASSWORD=$${NTFY_PASSWORD} ntfy ntfy access everyone $${NTFY_CHANNEL} $${GRANT_MODE:-ro}

.PHONY: grant-read-only # Grant user read-only access
grant-read-only:
	make --no-print-directory grant GRANT_MODE=ro

.PHONY: grant-read-write # Grant user read-write access
grant-read-write:
	make --no-print-directory grant GRANT_MODE=rw

.PHONY: grant-write-only # Grant user write-only access
grant-write-only:
	make --no-print-directory grant GRANT_MODE=wo

.PHONY: grant-anonymous-read-only # Grant anonymous read-only access to a single channel
grant-anonymous-read-only:
	make --no-print-directory grant-anonymous GRANT_MODE=ro

.PHONY: grant-anonymous-read-write # Grant anonymous read-write access to a single channel
grant-anonymous-read-write:
	make --no-print-directory grant-anonymous GRANT_MODE=rw

.PHONY: grant-anonymous-write-only # Grant anonymous write-only access to a single channel
grant-anonymous-write-only:
	make --no-print-directory grant-anonymous GRANT_MODE=wo

.PHONY: user-remove # Remove one user account
user-remove:
	@read -e -p "Enter the username to remove: " NTFY_USERNAME && docker compose --env-file=${ENV_FILE} exec ntfy ntfy user remove $${NTFY_USERNAME}

.PHONY: user-reset # Reset all privileges of one user
user-reset:
	@read -e -p "Enter the username to reset: " NTFY_USERNAME && docker compose --env-file=${ENV_FILE} exec ntfy ntfy access --reset $${NTFY_USERNAME}

.PHONY: reset-all-users # Reset all privileges for all users
reset-all-users:
	@docker compose --env-file=${ENV_FILE} exec ntfy ntfy access --reset

.PHONY: delete-all-users # Delete all users and permissions and reboot container
delete-all-users:
	@docker compose --env-file=${ENV_FILE} exec ntfy rm -f /etc/ntfy/user.db && make --no-print-directory reinstall && sleep 5 && make --no-print-directory access
