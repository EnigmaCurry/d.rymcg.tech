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

## Configure

Make sure you have followed the main project level [README.md](../README.md) to
understand how this project is setup.

Now in this directory, run :

```
make config
```

Answer the questions:

 * `POSTGRES_HOST` This is the public hostname that your PostgreSQL
   server will run on (the port, 5432, is publicly exposed on the
   docker host; Traefik is not used in this case).
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

## Local database

You can start a subshell with all the correct variable set for local
access with any postgresql client, eg. psql or dbeaver.

```
## Create subshell environment with connection details set in env vars:
make localdb
```

## Import sample databases

You can import the sample
[Chinook-database](https://github.com/lerocha/chinook-database), which is an
example Music store database.

```
make chinook
```

This creates a new database and role named `chinook` and adds the existing
`LIMITED_POSTGRES_USER` access to the role.

This uses [pgloader](https://github.com/dimitri/pgloader) to import the SQLite
version of the chinook database (translating to PostgreSQL on the fly!). As
pgloader is running directly inside the postgresql container, the import is
exceptionally fast. (orders of magnitude faster than running `\i Chinoook.sql`
from psql shell.)

You can use this as an example for loading any other dataset.

## Backup

Your databases may be configured to backup automatically with
[pgbackrest](https://pgbackrest.org/), which can be configured to be
stored on any combination of these storage backends:

 * Locally stored to a separate volume (`backup`) on the same Docker
   host. (`POSTGRES_PGBACKREST_LOCAL=true`)
 * Remotely stored to an S3 bucket on an external host.
   (`POSTGRES_PGBACKREST_S3=true`)

Pgbackrest can optionally encrypt your backups (eg. if you don't
control/trust your own S3 endpoint)
(`POSTGRES_PGBACKREST_ENCRYPTION_PASSPHRASE`). By default, there is no
passphrase set, and so encryption is disabled. If you set a
passphrase, it will enable encryption for all backups (local and
remote).

**Make sure you keep a copy of the .env file in a secure vault, as it
contains your S3 credentials, and your encryption passphrase,
either/both of which you will need in order to restore from backup!**

### Example with local backup to docker volume:

To configure a local backup, you simply need to configure the
following environment variables in your .env file. This information
can all be entered by hand, when you run `make config`:

 * `POSTGRES_PGBACKREST_LOCAL=true` - this must be set to `true` to enable local backup.
 * `POSTGRES_PGBACKREST_LOCAL_RETENTION_FULL` - the number of full backups to keep in the archive (eg. 2)
 * `POSTGRES_PGBACKREST_LOCAL_RETENTION_DIFF` - the number of differential backups to keep in the archive (eg. 4)

### Examples with remote S3 backup:

To configure a remote S3 backup, you simply need to configure the
following environment variables in your .env file. This information
can all be entered by hand, when you run `make config`:

You must provision the S3 endpoint and/or credentials beforehand, and
then answer the questions to fill in the information for these
variables:

 * `POSTGRES_PGBACKREST_S3=true` - this must be set to `true` to enable S3 backup.
 * `POSTGRES_PGBACKREST_S3_ENDPOINT` - the S3 endpoint domain name (eg. `s3.us-east-1.amazonaws.com`)
 * `POSTGRES_PGBACKREST_S3_REGION` - the S3 region name (eg.
   `us-east-1`, or leave it blank if your endpoint doesnt use regions)
 * `POSTGRES_PGBACKREST_S3_BUCKET` - the S3 bucket name (eg. `my-bucket`)
 * `POSTGRES_PGBACKREST_S3_KEY_ID` - the S3 API account ID (this is the bucket login)
 * `POSTGRES_PGBACKREST_S3_KEY_SECRET` - the S3 secret key (this is the bucket password)
 * `POSTGRES_PGBACKREST_S3_RETENTION_FULL` - the number of full backups to keep in the archive (eg. 4)
 * `POSTGRES_PGBACKREST_S3_RETENTION_DIFF` - the number of differential backups to keep in the archive (eg. 8)

#### Create a bucket on Minio (self-hosted S3 server)

Minio is an open-source self-hosted S3 server. You can easily install
Minio on your docker server. Follow the directions at
[minio](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/minio)
and especially [the instructions for creating a bucket, policy, and
credentials](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/minio#create-a-bucket)

The default bucket policy that the minio `make bucket` utility creates
will work fine. It is a little bit less restrictive than the policy
that the pgbackrest documentation suggests for you to use, but it will
work nonetheless. You may wish to login to the minio admin console and
create a new policy, and you can copy for the same policy shown in the
example below for Wasabi.

Quickstart:

```
d.rymcg.tech make minio destroy clean config install bucket
```

Enter the bucket name `postgres-apps` and choose the default for
everything else. Copy the endpoint, access-key, and secret-key for
entering into the postgres config later.

#### Create a bucket on Wasabi (commerical S3 service)

[Wasabi](https://wasabi.com/) is an inexpensive cloud storage vendor with an S3
compatible API, and with a pricing and usage model perfect for backups.

 * Create a wasabi account and [log in to the console](https://console.wasabisys.com/)
 * Click on `Buckets` in the menu, then click `Create Bucket`. Choose a unique
   name for the bucket. Select the region, then click `Create Bucket`.
 * Click on `Policies` in the menu, then click `Create Policy`. Enter
   any name for the policy, but its easiest to name it the same thing
   as the bucket. Copy and paste the full policy document as show
   below, into the policy form, careful to replace all instances of
   the string `BUCKET_NAME` (3 instances) with your chosen bucket
   name:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::BUCKET_NAME",
      "Condition": {"StringEquals":{"s3:prefix":["","apps-repo"],"s3:delimiter":["/"]}}
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::BUCKET_NAME",
      "Condition": {"StringLike":{"s3:prefix":["apps-repo/*"]}}
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::BUCKET_NAME/apps-repo/*"
    }
  ]
}
```

 * Once the policy document is edited, click `Create Policy`.

 * Click on `Users` in the menu, then click `Create User`.

   * Enter any username you like, but its easiest to name the user the same as
     the bucket.
   * Check the type of access as `Programatic`.
   * Click `Next`.
   * Skip the Groups screen.
   * On the Policies page, click the dropdown called `Attach Policy To User` and
   find the name of the policy you created above.
   * Click `Next`.
   * Review and click `Create User.`
   * View the Access and Secret keys. Click `Copy Keys To Clipboard`.
   * Paste the keys into a temporary buffer in your editor to save them, you
     will need to copy them into the script that you download in the next
     section.
   * You will need to know the [S3 endpoint URLs for
     wasabi](https://wasabi-support.zendesk.com/hc/en-us/articles/360015106031-What-are-the-service-URLs-for-Wasabi-s-different-storage-regions-)
     later, which are dependent on the Region you chose for the bucket. (eg.
     `s3.us-west-1.wasabisys.com`)


### Start backup now

Choose which backup you want to do, local or s3:

```
## Make local backup to docker volume
make backup-local

## Make remote backup to s3 bucket
make backup-s3
```

### Start restore now

This will shutdown the postgres service, DELETE all data, and restart
in maintaince mode, and restore the latest backup from S3:

Choose which backup you want to restore from:

```
## Restore from local backup:
make restore-local

## Restore from s3 backup:
make restore-s3
```

Note that you can restore with either a running instance, or from no
instance at all:

```
## Destroy the existing instance and restore from s3 and start it up:
d.rymcg.tech make postgresql destroy restore-s3 start
```

Note that in a real disaster scenario you will need to restore your
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file first, as it contains the S3
credentials and encryption passphrase necessarry to run the restore.


### Get backup information

You can see information about the latest backups performed:

```
make backup-info
```
