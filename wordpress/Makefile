# Update this to point to your d.ry repo
ROOT_DIR = ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
include ${ROOT_DIR}/_scripts/Makefile.projects-external
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} WP_INSTANCE=${instance}
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} WP_TRAEFIK_HOST "Enter the wp domain name" wp${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} WP_DB_ROOT_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} WP_DB_PASSWORD
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} WP_HTTP_AUTH default=no
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get WP_ANTI_HOTLINK) == "true" ]] && echo "yes" || echo "no") "Do you want to enable anti-hotlinking of images" "?" && ${BIN}/reconfigure ${ENV_FILE} WP_ANTI_HOTLINK=true || ${BIN}/reconfigure ${ENV_FILE} WP_ANTI_HOTLINK=false || true
	@echo ""
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get WP_ANTI_HOTLINK) == "true" ]] && ${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get WP_ANTI_HOTLINK_ALLOW_EMPTY_REFERER) == "true" ]] && echo "yes" || echo "no") "Should a client that sends an empty referer be allowed to view attachments" "?" && ${BIN}/reconfigure ${ENV_FILE} WP_ANTI_HOTLINK_ALLOW_EMPTY_REFERER=true || ${BIN}/reconfigure ${ENV_FILE} WP_ANTI_HOTLINK_ALLOW_EMPTY_REFERER=false || true
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get WP_WP2STATIC) == "true" ]] && echo "yes" || echo "no") "Do you want to create a static HTML wordpress export via wp2static" "?" && ${BIN}/reconfigure ${ENV_FILE} WP_WP2STATIC=true || ${BIN}/reconfigure ${ENV_FILE} WP_WP2STATIC=false || true
	@echo ""
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get WP_WP2STATIC) == "true" ]] && ${BIN}/reconfigure_ask ${ENV_FILE} WP_TRAEFIK_HOST_STATIC "Enter the static wp domain name" static${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true


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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:wp instance=@WP_INSTANCE traefik_host=@WP_TRAEFIK_HOST http_auth=WP_HTTP_AUTH http_auth_var=@WP_HTTP_AUTH ip_sourcerange=@WP_IP_SOURCERANGE enable_anti_hotlink=WP_ANTI_HOTLINK anti_hotlink_referers_extra=@WP_ANTI_HOTLINK_REFERERS_EXTRA anti_hotlink_allow_empty_referer=@WP_ANTI_HOTLINK_ALLOW_EMPTY_REFERER enable_wp2static=WP_WP2STATIC traefik_host_static=@WP_TRAEFIK_HOST_STATIC http_auth_static=WP_HTTP_AUTH_STATIC http_auth_static_var=@WP_HTTP_AUTH_STATIC ip_sourcerange_static=@WP_IP_SOURCERANGE_STATIC

.PHONY: shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec -it $${service:-wp} /bin/sh -c "/bin/bash || /bin/sh"
