ROOT_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

.PHONY: build
build:
	docker build -f $(dir $(lastword $(MAKEFILE_LIST)))/Dockerfile -t d-rymcg-tech $(ROOT_DIR)

.PHONY: test
test:
	docker run --rm \
	  -e DOCKER_CONTEXT=test \
	  -e SSH_HOST=docker.bananas.example.com \
	  -e SSH_USER=admin \
	  -e SSH_PORT=3214 \
	  -e ROOT_DOMAIN=bananas.example.com \
	  -e WHOAMI_TRAEFIK_HOST=whoami.bananas.example.com \
	  d-rymcg-tech \
	  bash -c "cat ~/.ssh/config && echo '---' && cat whoami/.env_test_default && echo '---' && cat .env_test"

PROJECTS ?=
DOCKER_CONTEXT ?= template
SSH_HOST ?= localhost
SSH_USER ?= root
SSH_PORT ?= 22

.PHONY: template-env
template-env:
	@if [ -z "$(PROJECTS)" ]; then echo "ERROR: PROJECTS is required (comma-separated list)" >&2; exit 1; fi
	@docker run --rm \
	  $(if $(ENV_FILE),--env-file $(ENV_FILE)) \
	  -e DOCKER_CONTEXT=$(DOCKER_CONTEXT) \
	  -e SSH_HOST=$(SSH_HOST) \
	  -e SSH_USER=$(SSH_USER) \
	  -e SSH_PORT=$(SSH_PORT) \
	  -e _PROJECTS=$(PROJECTS) \
	  d-rymcg-tech \
	  bash -c 'IFS=, read -ra projs <<< "$$_PROJECTS"; \
	    echo "## .env_$${DOCKER_CONTEXT}"; cat ".env_$${DOCKER_CONTEXT}"; \
	    for p in "$${projs[@]}"; do \
	      echo; echo "## $$p/.env_$${DOCKER_CONTEXT}_default"; \
	      cat "$$p/.env_$${DOCKER_CONTEXT}_default"; \
	    done'
