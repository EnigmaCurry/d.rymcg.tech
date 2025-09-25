# Tour of d.rymcg.tech

This guide will show you how to configure d.rymcg.tech on a fresh
Docker server with a suggested set of initial services. 

For a comprehensive list of all the serices provided by d.rymcg.tech,
please consult [README.md](README.md#services)

## Requirements

This guide assumes that you have already performed the following
steps:

  * Create your workstation (choose one):
 
    * [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Setup your workstation on Linux.
    * [WORKSTATION_WSL.md](WORKSTATION_WSL.md) - Setup your workstation on Windows (WSL).

  * Create your Docker server:
  
    * [DOCKER.md](DOCKER.md) - Create your Docker server on bare
      metal, VM, or cloud server.

All of the commands written in this guide are to be run on your
workstation:

  * Switch your workstation's Docker context to the server you wish to
    control:
    
```
d context
```

## Context config

```
d config
```

```
> This will make a configuration for the current docker context (insulon). Proceed? Yes
ROOT_DOMAIN: Enter the root domain for this context (eg. d.example.com)
: insulon.rymcg.tech
Configured .env_insulon
ENV_FILE=.env_insulon_default

> Is this server behind another trusted proxy using the proxy protocol? No
Set DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL=false
Set DEFAULT_CLI_ROUTE_LAYER_4_PROXY_PROTOCOL=false

> Do you want to save cleartext passwords in passwords.json by default? No
Set DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON=false
```

## Traefik

```
d make traefik config
```

## Acme-DNS

## Whoami

## Forgejo

## Traefik-Forward-Auth

## Postfix Relay

## Step-CA

## Docker Registry

## SFTP (and Thttpd)

## MinIO S3 (and Filestash)

## Homepage

## Nginx and PHP

## Jupyterlab
