# PostgreSQL database for public networks with mutual TLS authentication

This sets up all of the Public Key Infrastruture (PKI) to run a secure
[PostgreSQL](https://www.postgresql.org) server on the public internet, with TLS
encrypted connections and mutual (self-signed) certificate based authentication.
Simple TLS configuration is provided by [step-cli](https://github.com/smallstep/cli)

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
care for the server running backups and security updates for you, but even they
don't do mutual TLS auth yet, only IP address whitelisting). Or, you can roll
your own, which is what this document is all about.

So, if you've figured out this is what you really want, follow along ...

## This does not use Traefik

Unlike most of the other apps in this project, Traefik is not actually used
here. PostgreSQL has first class support for mutual TLS, and Traefik cannot
speak PostgreSQL protocol anyway. (The only thing Traefik could do is forward
raw TCP connections, but this wouldn't have much purpose other than perhaps the
IP whitelist, which you can also do on your firewall anyway. So instead, this
project maps the port directly on the external docker host network port.)

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
   
 * `POSTGRES_DB` The name of the database to create (this will also be the
   username).
 * `ALLOWED_IP_SOURCERANGE` The allowed client IP network range in CIDR format
   with netmask. To allow any client to connect enter `0.0.0.0/0` or to enter a
   specific IP address enter `x.x.x.x/32`.

## Install

To install the server, run:

```
make install
```

## Configure client

To use any client, you need the following information:

 * The hostname and port number of the PostgreSQL server.
 * The database name.
 * The username. (The PostgreSQL TLS `verify-full` option forces this to be the
   same as the database name.)
 * The client certificate (hostname_db_name.crt).
 * The client key (hostname_db_name.key).
 * The root CA certificate (hostname_ca.crt).

NOTE: The client certificate and key files are your authentication credentials.
You don't need any password! Keep these files safe!

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

## Using the certificates in Python (asyncpg) code

You can see how to use the certificates with the popular Python client,
[asyncpg](https://github.com/MagicStack/asyncpg) :


```python
import asyncpg
import asyncio
import ssl

HOSTNAME = "postgres.example.com"
DATABASE = "my_database"
PORT = 5432

async def main():
    # Load CA bundle for server certificate verification,
    # equivalent to sslrootcert= in DSN.
    sslctx = ssl.create_default_context(
        ssl.Purpose.SERVER_AUTH,
        cafile=f"{HOSTNAME}_ca.crt")
    # If True, equivalent to sslmode=verify-full, if False:
    # sslmode=verify-ca.
    sslctx.check_hostname = True
    # Load client certificate and private key for client
    # authentication, equivalent to sslcert= and sslkey= in
    # DSN.
    sslctx.load_cert_chain(
        f"{HOSTNAME}_{DATABASE}.crt",
        keyfile=f"{HOSTNAME}_{DATABASE}.key",
    )
    conn = await asyncpg.connect(
        host=HOSTNAME,
        port=PORT,
        user=DATABASE,
        ssl=sslctx)

    stmt = await conn.prepare('''SELECT 2 ^ $1''')
    print(f"2^10 == {await stmt.fetchval(10)} yea?")
    print(f"2^20 == {await stmt.fetchval(20)} yea?")

    await conn.close()

loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)
loop.run_until_complete(main())
```

## Firewall

As documented in the root project [README.md](../README.md#notes-on-firewall),
no firewall is included in this project. This means that anyone in the world can
TRY to login to your database. They won't be able to get in without the
certifcate, but they will still see the error message from PostgreSQL. So as an
additional security measure, you may wish to block port 5432 (or the port you
specify in your environment `EXTERNAL_TCP_PORT`) to all IP addresses other than
the one you want to have connect.

## Container psql session

Another way you can start a psql shell is this:

```
make psql
```

This connects your terminal through Docker to the psql shell, it doesn't use any
TLS connection at all, but instead runs through the SSH connection to your
remote docker service.
