# Registry

[Docker Registry](https://distribution.github.io/distribution/) is a
service to store and distribute Docker container images (OCI images)
to your Docker hosts (e.g., `docker push`, `docker pull`).

If you only have one Docker server, running a registry is kind of
pointless. Reasons you might need a registry are:

 * You have multiple Docker servers and you want an image cache that
   they can all share.
 * You have built your own custom images that you want to distribute.
 * You want to run [faasd](../faasd) and need a place to store your
   function container images.
 * You want to store images for any reason.

## Config

```
make config
```

Configure the hostname:

```stdout
REGISTRY_TRAEFIK_HOST: Enter the registry domain name (eg. registry.example.com)
: registry.d.example.com
```

The registry has a fully public API, so it is highly recommended to
configure the sentry authorization mechanism of your choice, which
will keep the registry secure from unauthorized users. Choose either
`HTTP Basic Authentication` (username+password) or `Mutual TLS (mTLS)`
(signed certificate):

```stdout
? Do you want to enable sentry authorization for admin push access? (No means complete free-for-all!)
  No
> Yes, with HTTP Basic Authentication
  Yes, with Mutual TLS (mTLS)

Enter the username for HTTP Basic Authentication
: ryan

Enter the passphrase for ryan (leave blank to generate a random passphrase)
: hunter2

Hashed password: ryan:$apr1$Rav9J1xZ$oKMnqMzcEequ6H2VBha6N0
Url encoded: https://ryan:hunter2@example.com/...

> Would you like to create additional usernames (for the same access privilege)? No

> Would you like to export the usernames and cleartext passwords to the file passwords.json? Yes
```

### Storage backend

By default, the registry stores images in a Docker volume. You can
optionally use an S3-compatible bucket (e.g., AWS S3, Cloudflare R2,
MinIO) for storage.

**NOTE: S3 storage is EXPERIMENTAL and may not work reliably with all
S3-compatible providers.**

```stdout
By default, Registry storage uses a Docker volume. Optionally, you can use an S3 bucket.
? Choose the storage backend:
> docker
  s3
```

If you choose `s3`, you will be prompted for the endpoint URL,
region, bucket name, access key, and secret key. For Cloudflare R2,
use `auto` as the region.

### Public read-only access

You can optionally allow anonymous (unauthenticated) read-only
access, so anyone can `docker pull` without `docker login`, while
`docker push` still requires authentication:

```stdout
> Do you want to allow public (unauthenticated) read-only pull access? Yes
```

### Pull-only credentials

You can configure separate pull-only credentials that allow
`docker pull` but not `docker push`. This uses the same auth
method as admin (HTTP Basic Authentication or mTLS) but with
separate credentials. This is mutually exclusive with public
read-only access. Admin credentials also work for pulling.

## Install

```
make install
```

## Login

Use `make login` to authenticate your Docker client with the
registry. This reads credentials from `passwords.json` if available,
and lets you choose which Docker context to log in from:

```
make login
```

```stdout
> Which Docker context do you want to login from? my-context
Login Succeeded
```

You can also log in manually:

```
docker login registry.example.com
```

## Push and pull images

Pull an image from the normal Docker registry for testing purposes:

```
docker pull docker.io/traefik/whoami:latest
```

Retag the image so that it belongs to your registry now:

```
docker tag docker.io/traefik/whoami:latest registry.example.com/traefik/whoami:latest
```

Push it to the new registry:

```
docker push registry.example.com/traefik/whoami:latest
```

## List tags

List all images and tags stored in the registry:

```
make list-tags
```

## Delete tags

Interactively select and delete images from the registry:

```
make delete-tags
```

This presents a multi-select menu of all images, confirms before
deleting, and optionally runs garbage collection afterward to reclaim
storage space.

## Garbage collection

Run garbage collection to remove unreferenced blobs and reclaim
storage space. This requires a temporary registry restart:

```
make garbage-collect
```

## S3 management

When using S3 storage, you can list and clean up the bucket contents
directly:

```
make s3-list     # List all files in the S3 bucket
make s3-clean    # Delete all files from the S3 bucket (with confirmation)
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
