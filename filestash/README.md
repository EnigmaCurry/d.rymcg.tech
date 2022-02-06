# filestash

[Filestash](https://github.com/mickael-kerjean/filestash) is a web-based file
manager, connecting to many different storage backends.

## Config

Run `make config` or copy `.env-dist` to `.env` and edit the variables:

 * `FILESTASH_TRAEFIK_HOST` the domain name for the filestash application
 * `FILESTASH_AUTH` the htpasswd encoded Basic Authentication credentials for
   your users.
   
All the rest of the setup is done inside the applications admin console.

Note: the application configuration is ephemeral; it is not stored to a volume
by default. [See the manual instructions for saving the applicaiton config to a
volume.](https://www.filestash.app/docs/install-and-upgrade/#optional-using-a-bind-mount-for-persistent-configuration)

## Run

Run `make install` or `docker-compose up -d`.

Run `make open` to open the main application page. This will pre-populate the
username and password, and open your browser to the page. (See the URL with the
username/password in your terminal.)

You must setup an admin account on first login, with a separate password.

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
