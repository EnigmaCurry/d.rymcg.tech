## Generic project Makefile header is included from ../_common/Makefile.generic

.PHONY: config-hook
config-hook: config-hook-basic-traefik
#### The standard Traefik questions are in config-hook-basic-traefik
#### Add additional config steps here:
	@[[ -z "$$(${BIN}/dotenv -f ${ENV_FILE} get ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_POSTGRES_PASSWORD)" ]] && ${BIN}/reconfigure ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_POSTGRES_PASSWORD=$$(openssl rand -base64 45) || true

.PHONY: override-hook
override-hook:
#### This sets the standard override variables for docker-compose.instance.yaml - add your own at the end:
	@${BIN}/docker_compose_override ${ENV_FILE} ${BASIC_OVERRIDES}

.PHONY: dev-sync
dev-sync:
	@${BIN}/dev-sync ${CREATE_TEMPLATE_PROJECT_NAME}_development flask

.PHONY: localdb # Open BASH shell with remote DB connection through SSH
localdb:
	@${BIN}/postgresql-tunnel ${ENV_FILE} database ${INSTANCE}

