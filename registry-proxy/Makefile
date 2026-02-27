ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} REGISTRY_PROXY_INSTANCE=$${instance:-default}
	@echo ""
	@${BIN}/reconfigure_compose_profiles_select ${ENV_FILE} dockerhub="Docker Hub (docker.io)" ghcr="GitHub Container Registry (ghcr.io)" quay="Quay.io (quay.io)" gcr="Google Container Registry (gcr.io)" k8s="Kubernetes registry (registry.k8s.io)"
	@echo ""
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q dockerhub && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_PROXY_DOCKERHUB_TRAEFIK_HOST "Enter the Docker Hub cache domain" dockerhub.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q ghcr && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_PROXY_GHCR_TRAEFIK_HOST "Enter the GHCR cache domain" ghcr.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q quay && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_PROXY_QUAY_TRAEFIK_HOST "Enter the Quay cache domain" quay.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q gcr && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_PROXY_GCR_TRAEFIK_HOST "Enter the GCR cache domain" gcr.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q k8s && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_PROXY_K8S_TRAEFIK_HOST "Enter the Kubernetes registry cache domain" k8s.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@echo ""
	@${BIN}/reconfigure_auth ${ENV_FILE} REGISTRY_PROXY
	@${BIN}/reconfigure_password ${ENV_FILE} REGISTRY_PROXY_HTTP_SECRET
	@echo ""

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:registry-proxy instance=@REGISTRY_PROXY_INSTANCE ip_sourcerange=@REGISTRY_PROXY_IP_SOURCERANGE http_auth=REGISTRY_PROXY_HTTP_AUTH http_auth_var=@REGISTRY_PROXY_HTTP_AUTH oauth2=REGISTRY_PROXY_OAUTH2 authorized_group=REGISTRY_PROXY_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=REGISTRY_PROXY_MTLS_AUTH mtls_authorized_certs=REGISTRY_PROXY_MTLS_AUTHORIZED_CERTS dockerhub_host=REGISTRY_PROXY_DOCKERHUB_TRAEFIK_HOST ghcr_host=REGISTRY_PROXY_GHCR_TRAEFIK_HOST quay_host=REGISTRY_PROXY_QUAY_TRAEFIK_HOST gcr_host=REGISTRY_PROXY_GCR_TRAEFIK_HOST k8s_host=REGISTRY_PROXY_K8S_TRAEFIK_HOST

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=dockerhub

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
