ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_HOST "Enter the wireguard domain name" wireguard${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} WIREGUARD_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_PEERS "Enter the comma separated list of peer names (alphanumeric only, no spaces, no dashes, no underscores)"

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:wireguard instance=@WIREGUARD_INSTANCE public_peer_ports=WIREGUARD_PUBLIC_PEER_PORTS ipv6_enable=WIREGUARD_IPV6_ENABLE ipv6_docker_subnet=WIREGUARD_IPV6_DOCKER_SUBNET

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=wireguard

.PHONY: show-wireguard-peers
show-wireguard-peers:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/sh -c 'ls /config/peer*/*.conf | xargs -iXX sh -c "echo && echo \#\#\ XX && cat XX"'

.PHONY: show-wireguard-peers-qr
show-wireguard-peers-qr:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/sh -c 'ls /config/peer*/*.conf | xargs -iXX sh -c "echo && echo \#\#\ XX && qrencode -t ansiutf8 < XX"'
