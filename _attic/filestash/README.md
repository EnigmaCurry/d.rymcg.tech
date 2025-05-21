# filestash

[Filestash](https://github.com/mickael-kerjean/filestash) is a web-based file
manager, connecting to many different storage backends.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

This configuration requires HTTP Basic Authentication in front of the
application. This is due to the fact that **I consider filestash to be
insecure by default**, and because it performs the backend
authentication *on the client*. I have enforced HTTP basic
authentication as a simple mitigation against leaking these
credentials publicly, however *you must trust all of your users as if
you were giving them your backend storage credentials directly.* If
you create a storage backend, and save the default password, the
backend storage credentials are visible to all client users.

## Config

Run `make config` or copy `.env-dist` to `.env_${DOCKER_CONTEXT}_default` and edit the variables:

 * `FILESTASH_TRAEFIK_HOST` the domain name for the filestash application
 * `FILESTASH_AUTH` the htpasswd encoded Basic Authentication credentials for
   your users.

All the rest of the setup is done inside the applications admin console.

## Run

Run `make install` or `docker-compose up -d`.

Run `make open` to open the main application page. This will pre-populate the
username and password, and open your browser to the page. (See the URL with the
username/password in your terminal.)

You must setup an admin account on first login, with a *separate* password.

Open the admin page to create at least one storage backend for your
users to connect to:

```
make admin
```

## Setup example with S3 storage

 * Setup the [minio](../minio) application to serve as a storage backend.
   * After installing minio, (in the minio directory) run `make bucket` to
     create a bucket for filestash to use.
 * Once the bucket is created, open the filestash admin console (from this
   directory): `make admin`.
 * At the admin console, click `Backends`.
 * Choose the storage backends you wish to enable. For this example, I remove
all of them, by clicking the X icons, except for `S3`.
 * For the S3 connection, enter the details:
   * `Label`
   * `Access key id` - copy this access key from the output of `make bucket`
   * `Secret access key` - copy this secret key from the output of `make bucket`
   * `Endpoint` (must click under `Advanced`) - copy this endpoint from the output of `make bucket`
 * Make sure ALL of the options have checkmarks next to them, this will disable
   these settings on the login page.

Run `make open` and the main page will open in the browser. Click `Connect` and
you will see the folder specific to the S3 bucket storage. Click the folder and
use it now like you would Dropbox.

Give users the URL that is displayed in the terminal, this includes the username
and password in the URL itself.
