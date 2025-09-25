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

## Traefik

## Acme-DNS

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
