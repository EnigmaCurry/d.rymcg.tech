ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} REGISTRY_CACHE_INSTANCE=$${instance:-default}
	@echo ""
	@${BIN}/reconfigure_compose_profiles_select ${ENV_FILE} dockerhub="Docker Hub (docker.io)" ghcr="GitHub Container Registry (ghcr.io)" quay="Quay.io (quay.io)" gcr="Google Container Registry (gcr.io)" k8s="Kubernetes registry (registry.k8s.io)" gitlab="GitLab Container Registry (registry.gitlab.com)" ecr="Amazon ECR Public (public.ecr.aws)" lscr="LinuxServer Container Registry (lscr.io)" codeberg="Codeberg Container Registry (codeberg.org)"
	@echo ""
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q dockerhub && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_DOCKERHUB_TRAEFIK_HOST "Enter the Docker Hub cache domain" dockerhub.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q ghcr && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_GHCR_TRAEFIK_HOST "Enter the GHCR cache domain" ghcr.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q quay && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_QUAY_TRAEFIK_HOST "Enter the Quay cache domain" quay.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q gcr && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_GCR_TRAEFIK_HOST "Enter the GCR cache domain" gcr.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q k8s && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_K8S_TRAEFIK_HOST "Enter the Kubernetes registry cache domain" k8s.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q gitlab && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_GITLAB_TRAEFIK_HOST "Enter the GitLab registry cache domain" gitlab.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q ecr && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_ECR_TRAEFIK_HOST "Enter the ECR Public cache domain" ecr.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q lscr && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_LSCR_TRAEFIK_HOST "Enter the LinuxServer registry cache domain" lscr.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep -q codeberg && ${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_CACHE_CODEBERG_TRAEFIK_HOST "Enter the Codeberg registry cache domain" codeberg.registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@echo ""
	@${BIN}/reconfigure_auth ${ENV_FILE} REGISTRY_CACHE
	@${BIN}/reconfigure_password ${ENV_FILE} REGISTRY_CACHE_HTTP_SECRET
	@echo ""

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:registry-cache instance=@REGISTRY_CACHE_INSTANCE ip_sourcerange=@REGISTRY_CACHE_IP_SOURCERANGE http_auth=REGISTRY_CACHE_HTTP_AUTH http_auth_var=@REGISTRY_CACHE_HTTP_AUTH oauth2=REGISTRY_CACHE_OAUTH2 authorized_group=REGISTRY_CACHE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=REGISTRY_CACHE_MTLS_AUTH mtls_authorized_certs=REGISTRY_CACHE_MTLS_AUTHORIZED_CERTS dockerhub_host=REGISTRY_CACHE_DOCKERHUB_TRAEFIK_HOST ghcr_host=REGISTRY_CACHE_GHCR_TRAEFIK_HOST quay_host=REGISTRY_CACHE_QUAY_TRAEFIK_HOST gcr_host=REGISTRY_CACHE_GCR_TRAEFIK_HOST k8s_host=REGISTRY_CACHE_K8S_TRAEFIK_HOST gitlab_host=REGISTRY_CACHE_GITLAB_TRAEFIK_HOST ecr_host=REGISTRY_CACHE_ECR_TRAEFIK_HOST lscr_host=REGISTRY_CACHE_LSCR_TRAEFIK_HOST codeberg_host=REGISTRY_CACHE_CODEBERG_TRAEFIK_HOST

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=dockerhub

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
