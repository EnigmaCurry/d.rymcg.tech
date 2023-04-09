## ROOT_DIR is the full path to the git clone of d.rymcg.tech:
ROOT_DIR = ..
## This Makefile inherits abilities from d.rymcg.tech Makefiles
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

BASIC_OVERRIDES = project=:audiobookshelf context=:"${DOCKER_CONTEXT}" instance=AUDIOBOOKSHELF_INSTANCE traefik_host=AUDIOBOOKSHELF_TRAEFIK_HOST traefik_host_var=:AUDIOBOOKSHELF_TRAEFIK_HOST http_auth=AUDIOBOOKSHELF_HTTP_AUTH http_auth_var=:AUDIOBOOKSHELF_HTTP_AUTH ip_sourcerange_var=:AUDIOBOOKSHELF_IP_SOURCERANGE development_mode=AUDIOBOOKSHELF_DEVELOPMENT_MODE

.PHONY: config-hook-basic-traefik
config-hook-basic-traefik:
### config-hook is for the custom configuration the user must enter when running `make config`:
### reconfigure_ask will ask the user to enter the value for a variable, with the given prompt, with the given default value, and save it to the env file:
	@${BIN}/reconfigure_ask ${ENV_FILE} AUDIOBOOKSHELF_TRAEFIK_HOST "Enter the audiobookshelf domain name" audiobookshelf${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
### reconfigure will directly set a value in the env file:
	@${BIN}/reconfigure ${ENV_FILE} AUDIOBOOKSHELF_INSTANCE=$${instance:-default}
### configure IP filter:
	@${BIN}/reconfigure_ask ${ENV_FILE} AUDIOBOOKSHELF_IP_SOURCERANGE "Enter the client IP Address range filter (CIDR)" 0.0.0.0/0
### Configure HTTP Auth:
	@(${BIN}/confirm $$(test -n "$$(${BIN}/dotenv -f ${ENV_FILE} get AUDIOBOOKSHELF_HTTP_AUTH)" && echo yes || echo no) "Do you want to enable HTTP Basic Authentication" "?" && ${BIN}/reconfigure_htpasswd ${ENV_FILE} AUDIOBOOKSHELF_HTTP_AUTH) || ${BIN}/reconfigure ${ENV_FILE} AUDIOBOOKSHELF_HTTP_AUTH=''
	@(${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get AUDIOBOOKSHELF_DEVELOPMENT_MODE)" == "true" && echo yes || echo no) "Do you want to enable live-reload development mode" "?" && ${BIN}/reconfigure ${ENV_FILE} AUDIOBOOKSHELF_DEVELOPMENT_MODE=true) || ${BIN}/reconfigure ${ENV_FILE} AUDIOBOOKSHELF_DEVELOPMENT_MODE=false

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

