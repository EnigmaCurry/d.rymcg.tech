# Integrating external projects with d.rymcg.tech

You may create your own external projects, and/or integrate your
existing docker-compose projects, including from external git
repositories, and have them use the same d.rymcg.tech framework.

 * Create a new project directory, or clone your existing project, to
   any directory. (It does not need to be a sub-directory of
   `d.rymcg.tech`, but it can be).
 * In your own project repository directory, create the files for
   `docker-compose.yaml`, `docker-compose.instance.yaml`, `Makefile`,
   `.env-dist`, `.gitignore`and `README.md`. As an example, you can
   use any of the d.rymcg.tech sub-projects, like [whoami](whoami), or
   take a look at the
   [flask-template](https://github.com/EnigmaCurry/flask-template/).

Create the `Makefile` in your own separate repository so that it
includes the main d.rymcg.tech `Makefile.projects` file from
elsewhere:

```
## Example Makefile in your own project repository:

# ROOT_DIR can be a relative or absolute path to the d.rymcg.tech directory:
ROOT_DIR = ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} EXAMPLE_TRAEFIK_HOST "Enter the example domain name" example.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} EXAMPLE_OTHER_VAR "Enter the example other variable"
```

By convention, external project Makefiles should always hardcode the
enigmacurry git vendor path: `ROOT_DIR = ${HOME}/git/vendor/enigmacurry/d.rymcg.tech`, 
(but you may want to use your own directory if you have forked this
project and you have introduced unmerged changes):

```
## As long as everyone uses this same ROOT_DIR, then we can all share the same configs:
## (You might also create this path as a symlink, if you don't like this convention):
ROOT_DIR = ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
```

A minimal `Makefile`, like the one above, should include a
`config-hook` target that reconfigures your `.env` file based upon the
example variables given in `.env-dist`. This is what the user will
have to answer qusetions for when running `make config` for your
project.

Now in your own project directory, you can use all the regular `make`
commands that d.rymcg.tech provides:

```
make config
make install
make open
# etc
```
