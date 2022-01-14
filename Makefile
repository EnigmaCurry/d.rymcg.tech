ROOT_DIR = .

.PHONY: help # Show this help screen
help:
	@echo "Main Makefile help :"
	@grep -h '^.PHONY: .* #' Makefile ${ROOT_DIR}/_scripts/Makefile.globals | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20

include _scripts/Makefile.globals

.PHONY: config # Configure main variables
config:
	@echo TODO	

.PHONY: build # build all container images
build: build-traefik-htpasswd
