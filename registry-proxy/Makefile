ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} REGISTRY_PROXY_INSTANCE=$${instance:-default}
	@echo "## Docker Hub (docker.io) is always cached automatically."
	@${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_PROXY_REGISTRIES "Enter additional registries to cache (space-separated)" "k8s.gcr.io gcr.io quay.io ghcr.io"
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_PROXY_AUTH_REGISTRIES "Enter upstream registry auth (hostname:user:pass, space-separated, blank for none)"
	@echo ""

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:registry-proxy instance=@REGISTRY_PROXY_INSTANCE ip_sourcerange=@REGISTRY_PROXY_IP_SOURCERANGE

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=proxy

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
