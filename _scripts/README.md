# _scripts

This directory contains *optional* bash scripts to help configure things.

## What's optional exactly?

Every project here is created to be a simple docker-compose project, configured
*entirely* by static `.env` files. So you won't need *any* scripts nor
Makefiles, as long as you edit the `.env` files by hand, and just run
`docker-compose` directly.

These are helpers only, to help create `.env` files, and to automate repetitive admin tasks.
