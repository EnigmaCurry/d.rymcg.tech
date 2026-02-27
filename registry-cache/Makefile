ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_TRAEFIK_HOST "Enter the registry cache domain name" registry-cache${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} REGISTRY_CACHE_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_PROXY_REMOTEURL "Enter the upstream registry URL to mirror" https://registry-1.docker.io
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_PROXY_USERNAME "Enter the upstream registry username (blank for anonymous)"
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_PROXY_PASSWORD "Enter the upstream registry password (blank for anonymous)"
	@${BIN}/reconfigure_auth ${ENV_FILE} REGISTRY_CACHE
	@${BIN}/reconfigure_password ${ENV_FILE} REGISTRY_CACHE_HTTP_SECRET
	@echo ""

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:registry-cache instance=@REGISTRY_CACHE_INSTANCE traefik_host=@REGISTRY_CACHE_TRAEFIK_HOST http_auth=REGISTRY_CACHE_HTTP_AUTH http_auth_var=@REGISTRY_CACHE_HTTP_AUTH ip_sourcerange=@REGISTRY_CACHE_IP_SOURCERANGE oauth2=REGISTRY_CACHE_OAUTH2 authorized_group=REGISTRY_CACHE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=REGISTRY_CACHE_MTLS_AUTH mtls_authorized_certs=REGISTRY_CACHE_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=registry

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
