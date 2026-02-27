ROOT_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

.PHONY: build
build:
	docker build -f $(dir $(lastword $(MAKEFILE_LIST)))/Dockerfile -t d-rymcg-tech $(ROOT_DIR)

.PHONY: test
test:
	docker run --rm \
	  -e DOCKER_CONTEXT=test \
	  -e SSH_HOST=example.com \
	  -e ROOT_DOMAIN=d.example.com \
	  -e WHOAMI_TRAEFIK_HOST=whoami.d.example.com \
	  d-rymcg-tech \
	  bash -c "cat whoami/.env_test_default && echo '---' && cat .env_test"
