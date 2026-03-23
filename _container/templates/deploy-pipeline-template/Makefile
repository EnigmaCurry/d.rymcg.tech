D ?= d.rymcg.tech
SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.PHONY: config
config: ## Interactive config wizard — build encrypted config for a context
	@D=$(D) ./admin.sh config

.PHONY: ci
ci: ## Configure Woodpecker CI — activate repo and set secrets
	@D=$(D) ./admin.sh ci

.PHONY: view
view: ## Decrypt and display a config file
	@D=$(D) ./admin.sh view

.PHONY: edit
edit: ## Edit a config file with sops
	@D=$(D) ./admin.sh edit
