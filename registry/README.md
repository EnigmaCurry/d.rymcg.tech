# registry

## Config

```
make config
```

Configure the hostname:

```stdout
REGISTRY_TRAEFIK_HOST: Enter the registry domain name (eg. registry.example.com)
: registry.d.example.com
```

It is highly recommended to configure some form of sentry
authorization in front of your registry, this will keep it safe from
tampering by unauthorized users. Choose either `HTTP Basic
Authentication` or `Mutual TLS (mTLS)`:

```stdout
? Do you want to enable sentry authorization in front of this app (effectively making the entire site private)?  
  No
> Yes, with HTTP Basic Authentication
  Yes, with Oauth2
  Yes, with Mutual TLS (mTLS)

Enter the username for HTTP Basic Authentication
: ryan

Enter the passphrase for ryan (leave blank to generate a random passphrase)
: hunter2

Hashed password: ryan:$apr1$Rav9J1xZ$oKMnqMzcEequ6H2VBha6N0
Url encoded: https://ryan:hunter2@example.com/...

> Would you like to create additional usernames (for the same access privilege)? No

> Would you like to export the usernames and cleartext passwords to the file passwords.js
n? No
```

## Install

```
make install
```

## Configure client

To use the registry, configure the docker client to use it:

```
docker login registry.example.com
```

Enter your credentials for HTTP Basic Authentication:

```stdout
Username: ryan
Password: 
WARNING! Your password will be stored unencrypted in /home/ryan/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credential-stores

Login Succeeded
```

Pull an image from the normal Docker registry for testing purposes:

```
docker pull docker.io/traefik/whoami:latest
```

Retag the image so that it belongs to your registry now:

```
docker tag docker.io/traefik/whoami:latest registry.example.com/traefik/whoami:latest
```

Push it to your registry:

```
docker push registry.example.com/traefik/whoami:latest

# The push refers to repository [registry.example.com/traefik/whoami]
# 298b6a4a6489: Pushed 
# a1b937ed548c: Pushed 
# 01d1702a867e: Pushed 
# latest: digest: sha256:c899811bc4a1f63a1273c612e15f1bea6514a19c7b08143dbbdef3e8f882c38d size: 948
```

## Mutual TLS (mTLS)

If you choose the mTLS sentry authorization with
[step-ca](../step-ca), you can configure your docker client to use
your client certificate and key:

On the client computer:

 * Create a directory under `/etc/docker/certs.d` matching the
   registry hostname (e.g.,
   `/etc/docker/certs.d/registry.example.com/`).
 * In this directory create three files, named:
 
   * `ca.crt` - the Step-CA public CA cert.
   * `client.cert` - the client's public cert.
   * `client.key` - the client's private key.

There is no need to run `docker login` when using mTLS.

## Restrict access by IP address

By default the access is allowed to `0.0.0.0/0` which allows all
traffic. Restrict access to your list of subnets, for example:

```
make reconfigure var=REGISTRY_IP_SOURCERANGE=192.168.1.0/24,10.13.13.0/24
```

And then reinstall:

```
make install
```

## Instances

If you need to store images with different access credentials, you
should create a separate instance:

```
make instance instance=my-other-registry
```

```stdout
REGISTRY_TRAEFIK_HOST: Enter the registry domain name (eg. registry.example.com)
: my-other-registry.example.com
```

Install it like before, choose new authentication credentials, and
access it at the new hostname.
