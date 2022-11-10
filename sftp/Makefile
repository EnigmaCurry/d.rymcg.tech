ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@test -f .env_${DOCKER_CONTEXT} || (cp .env-dist .env_${DOCKER_CONTEXT} && echo "Created .env_${DOCKER_CONTEXT}")
	@echo "TODO: please just edit .env_${DOCKER_CONTEXT} manually."
