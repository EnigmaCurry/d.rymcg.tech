# Wordpress for d.rymcg.tech
This is a wordpress implementation for [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech). 

## About
d.rymcg allows you to easily self host many personal apps and services with traefik routing domains and subdomains to appropriate containers.

## Setup
- Follow the instructions at [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech).
- Update the Makefile in this repo to point to the d.rymcg.tech repo ROOT on your system.
- `make config`
- `make install`
- `make status`

## Testing / Destroying
- `make destroy` will delete everything in the instance
- `make clean` will delete your configured .env and derived compose files.

