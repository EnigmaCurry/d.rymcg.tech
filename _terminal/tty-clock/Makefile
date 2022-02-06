ROOT_DIR = ../..
include ../../_scripts/Makefile.help-basic
include ../../_scripts/Makefile.globals

# Switch to podman by setting DOCKER=podman environment variable
DOCKER ?= docker
IMAGE ?= localhost/tty-clock
GIT_SRC ?= https://github.com/EnigmaCurry/tty-clock.git\#master
TIMEZONE ?= UTC
CLOCK_ARGS ?= -c -s -C 3 -b

.PHONY: build # Build container image
build:
	${DOCKER} build --build-arg=TIMEZONE=${TIMEZONE} -t ${IMAGE} ${GIT_SRC}

.PHONY: clock # Run the clock
clock:
	@${DOCKER} inspect ${IMAGE} 2>&1 >/dev/null || make build
	@echo "# Run this command to start the clock:"
	@echo "# Add --help to see additional options:"
	${DOCKER} run --rm -it  -e TZ=${TIMEZONE} ${IMAGE} tty-clock ${CLOCK_ARGS}
