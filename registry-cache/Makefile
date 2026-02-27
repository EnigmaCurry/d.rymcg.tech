ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} REGISTRY_CACHE_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_PORT "Enter the host port for the proxy" 3128
	@${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_REGISTRIES "Enter additional registries to cache (space-separated)" "k8s.gcr.io gcr.io quay.io ghcr.io"
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_AUTH_REGISTRIES "Enter upstream registry auth (hostname:user:pass, space-separated, blank for none)"
	@echo ""

.PHONY: override-hook
override-hook:
	@echo

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=proxy

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
