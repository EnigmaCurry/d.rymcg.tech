# Self-hosted PostgreSQL DBaaS with mutual TLS authentication

This sets up all of the Public Key Infrastruture (PKI) to run a secure
[PostgreSQL](https://www.postgresql.org) DBaaS (Database as a Service) suitable
to run on the public internet, with TLS encrypted connections and mutual
(self-signed) certificate based authentication. Simple TLS configuration is
provided by [step-cli](https://github.com/smallstep/cli).

This configuration is also suitable for private/offline networks, and will still
enforce mutual TLS.

## "Cloud" PostgreSQL?

Normally you want your database installed as close to your application server as
possible. This is to reduce the latency of round trip network access patterns.
(This is why SQLite is so fast, because there is no network, and the database is
literally the same process as your app). For PostgreSQL, since it is a network
based server, this usually means that you want to install it on the same Docker
server that your application is running on, or at least on another local server
on the same private backend network.

Additionally, if your database server and application server are both on the
same small/segmented, and secure LAN (like a docker virtual network).. then you
don't need to use an encrypted connection. Its faster that way too, and
so most people don't use TLS with postgres because they don't need it.

However, there are things such as cloud databases, and database as a service,
which let you connect to a database running in a far away network. These things
serve a good purpose, but with the obvious downsides of increased latency and
decreased availability due to network conditons, and a greatly increased attack
surface. But you can pay someone else to run a fully managed PostgreSQL database
for you (like DigitalOcean; they offer PostgreSQL as a Service, and they will
take care for the server running backups and security updates for you, but even they
don't do mutual TLS auth yet, only IP address whitelisting). Or, you can roll
your own, which is what this document is all about.

So, if you've figured out this is what you really want, follow along ...

## Extensions

PostgreSQL supports extensions which are custom plugins you can install to
extend the feature set of PostgreSQL. These must be compiled from source code,
installed, and enabled per database. This configuration automates this process
as part of its customized Dockerfile (only one so far; pg_rational).

[pg_rational](https://github.com/begriffs/pg_rational) is a PostgreSQL extension
for representing pure fractions as a single database column. This enables you to
efficiently store user-generated re-orderable lists of any kind, like to-do
lists, or music playlists. See the blog post written by the same pg_rational
author: [User-defined Order in
SQL](https://begriffs.com/posts/2018-03-20-user-defined-order.html)


## This does not use Traefik

Unlike most of the other apps in this project (d.rymcg.tech), Traefik is not
actually used here. PostgreSQL has first class support for mutual TLS, and
Traefik cannot speak PostgreSQL protocol anyway. (The only thing Traefik could
do is forward raw TCP connections, but this wouldn't have much purpose other
than perhaps the IP whitelist, which you can also do on your firewall anyway. So
instead, this project maps the port directly on the external docker host network
port.)

## This does not do backups (yet)

This will probably eventually incorporate
[EnigmaCurry/postgresql-backup-s3](https://github.com/EnigmaCurry/postgresql-backup-s3)
to automatically backup and upload to S3. But its not been done yet!

## Configure

Make sure you have followed the main project level [README.md](../README.md) to
understand how this project is setup.

Now in this directory, run :

```
make config
```

Answer the questions:

 * `POSTGRES_TRAEFIK_HOST` This is the public hostname that your PostgreSQL
   server will run on. (Traefik is not actually used, see notes above. However,
   the `*_TRAEFIK_HOST` naming scheme is used throughout this project, so this
   name is appropriate still for the purpose of indicating the external host
   name.)
 * `POSTGRES_DB` The name of the database to create.
 * `ALLOWED_IP_SOURCERANGE` The allowed client IP network range in CIDR format
   with netmask. To allow any client to connect enter `0.0.0.0/0` or to enter a
   specific IP address enter `x.x.x.x/32`. (Note: this filtering is done by
   PostgreSQL itself, but see [Firewall](#firewall) to improve this security.)

## Install

To install the server, run:

```
make install
```

## Configure client

To use any client, you will need the following information, typically
represented by the following standard [postgresql/psql environment
variables](https://www.postgresql.org/docs/current/libpq-envars.html) (Most
third-party clients will also respect these environment variables too, but for
some clients you may need to type this information into some other config file,
or enter them in to a Settings panel yourself..) :

 * `PGHOST`: The hostname and port number of the PostgreSQL server.
 * `PGPORT`: The TCP port of the database server.
 * `PGDATABASE`: The database name.
 * `PGUSER`: The username to connect as.
 * `PGSSLMODE`: The TLS (SSL) mode. This should always be set to `verify-full`
   to enable mutual TLS.
 * `PGSSLCERT`: The full path to the client certificate (hostname_db_name.crt).
 * `PGSSLKEY`: The full path to the client key (hostname_db_name.key). Some
   clients (DBeaver) need a differently formatted key (hostname_db_name.pk8.key)
   which is `DER` formatted.
 * `PGSSLROOTCERT`: The full path to the root CA certificate (hostname_ca.crt).

**NOTE**: *The client certificate and key files **are** your authentication
credentials (no password). The certificates themselves are not password
protected! Keep these files safe!*

To download the client credentials from the server, run:

```
make client
```

This will create the certificate, key, and CA files in this same directory.
(They are ignored via `.gitignore`.) The full `psql` command is echoed to the
terminal, you can copy and paste it directly to start a `psql` shell. Enjoy!

When you connect via `psql` notice the connection details are printed:

```
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
```

Try connecting to a different (non-existing) database name, and you should see it fail with the following message:

```
psql: error: FATAL:  no pg_hba.conf entry for host "x.x.x.x", user "postgres", database "not-existing-database", SSL encryption
```

This is because the key is only valid for the particular set of credentials,
combining username + database + client certificate. All other connections are
refused.

`make clean` will remove all local copies of these keys and certificates (same
as running `rm *.crt *.key`)

## Re-issuing certificates

If you need to reset the TLS certitificate PKI, (maybe you accidentally exposed
one your keys and you want to create brand new ones) you can run:

```
make certificates
```

You will also need to re-run `make client` to download the new certificates for
your client to use.

## Using the certificates in Python (asyncpg) code

You can see how to use the certificates with the popular Python client,
[asyncpg](https://github.com/MagicStack/asyncpg) :


```python
import asyncio
import os

import asyncpg


async def main():
    ## No need to specify hostname, database, certificates etc in code.
    ## All connection details are loaded from standard PG* env vars:
    conn = await asyncpg.connect()

    stmt = await conn.prepare("select '1/3'::rational + '2/7';")
    print(f"1/3 + 2/7 == {await stmt.fetchval()} yea?")

    await conn.close()


asyncio.run(main())
```

## Firewall

The `ALLOWED_IP_SOURCERANGE` variable enables IP filtering directly inside
PostgreSQL (`pg_hba.conf`) to only allow access from clients in a certain IP
address range. However, using this setting alone, without an additional
firewall, means that any client will still be able to *attempt* a connection,
which is still undesirable and could open you to a denial of service type
attack.

As documented in the root project [README.md](../README.md#notes-on-firewall),
you are expected to provide your own firewall. Without it, this means that
anyone in the world can TRY to login to your database. They won't be able to get
in without the certifcate, but they will still be talking to the database
server, and will see the error message from PostgreSQL. So as an additional
security measure, you may wish to block port `5432` (or the port you specify in
your environment `EXTERNAL_TCP_PORT`) to all IP addresses other than the one you
want to have connect.

## Container psql session as superuser

To connect to the database with superuser privileges, run:

```
make psql
```

This connects your terminal through Docker to the psql shell, it doesn't use any
TLS connection at all, but instead runs through the SSH connection to your
remote docker service and connects directly to the unix domain socket for
postgres. This connects you to the database as the `root` superuser. This is the
only way that the `root` user is allowed to connect.

## Import sample databases

You can import the sample
[Chinook-database](https://github.com/lerocha/chinook-database), which is an
example Music store database.

```
make import-chinook
```

This creates a new database and role named `chinook` and adds the existing
`LIMITED_POSTGRES_USER` access to the role.

This uses [pgloader](https://github.com/dimitri/pgloader) to import the SQLite
version of the chinook database (translating to PostgreSQL on the fly!). As
pgloader is running directly inside the postgresql container, the import is
exceptionally fast. (orders of magnitude faster than running `\i Chinoook.sql`
from psql shell.)

You can use this as an example for loading any other dataset.

