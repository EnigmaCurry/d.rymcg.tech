## Generic project Makefile header is included from ../_common/Makefile.generic

.PHONY: config-hook
config-hook: config-hook-basic-traefik
#### The standard Traefik questions are in config-hook-basic-traefik
#### Add additional config steps here:
	@echo ""

.PHONY: override-hook
override-hook:
#### This sets the standard override variables for docker-compose.instance.yaml - add your own at the end:
	@${BIN}/docker_compose_override ${ENV_FILE} ${BASIC_OVERRIDES}

