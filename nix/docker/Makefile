ROOT_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

.PHONY: build
build:
	cd $(ROOT_DIR) && git archive HEAD | docker build -f nix/docker/Dockerfile -t d-rymcg-tech -

PROJECTS ?=
DOCKER_CONTEXT ?= template
SSH_HOST ?= localhost
SSH_USER ?= root
SSH_PORT ?= 22

.PHONY: test
test:
	@if [ -z "$(ENV_FILE)" ]; then echo "ERROR: ENV_FILE is required" >&2; exit 1; fi
	@docker run --rm \
	  --env-file $(ENV_FILE) \
	  -e DOCKER_CONTEXT=$(DOCKER_CONTEXT) \
	  -e SSH_HOST=$(SSH_HOST) \
	  -e SSH_USER=$(SSH_USER) \
	  -e SSH_PORT=$(SSH_PORT) \
	  d-rymcg-tech \
	  bash -c 'BIN=_scripts; \
	    for f in .env_* */.env_*; do \
	      [ -f "$$f" ] || continue; \
	      echo "## $$f"; $$BIN/dotenv -f "$$f" parse; echo; \
	    done'

.PHONY: template-env
template-env:
	@if [ -z "$(PROJECTS)" ]; then echo "ERROR: PROJECTS is required (comma-separated list)" >&2; exit 1; fi
	@docker run --rm \
	  $(if $(ENV_FILE),--env-file $(ENV_FILE)) \
	  -e DOCKER_CONTEXT=$(DOCKER_CONTEXT) \
	  -e SSH_HOST=$(SSH_HOST) \
	  -e SSH_USER=$(SSH_USER) \
	  -e SSH_PORT=$(SSH_PORT) \
	  -e SSH_KEY_SCAN=false \
	  -e _PROJECTS=$(PROJECTS) \
	  d-rymcg-tech \
	  bash -c 'BIN=_scripts; IFS=, read -ra projs <<< "$$_PROJECTS"; \
	    echo "## .env_$${DOCKER_CONTEXT}"; $$BIN/dotenv -f ".env_$${DOCKER_CONTEXT}" parse; \
	    for p in "$${projs[@]}"; do \
	      echo; echo "## $$p/.env_$${DOCKER_CONTEXT}_default"; \
	      $$BIN/dotenv -f "$$p/.env_$${DOCKER_CONTEXT}_default" parse; \
	    done'
