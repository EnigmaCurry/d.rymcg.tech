# Traefik HTTP Basic Authentication

Some of the projects contained in the parent project are configured for HTTP
Basic Authentication (and any of them can be modified to do so), such that a
username/password is required by the web browser *before* accessing the page.
This is accomplished using the [Traefik BasicAuth
middleware](https://doc.traefik.io/traefik/middlewares/http/basicauth/). The
applications are each configured with their own `*_HTTP_AUTH` variable
containing the list of allowed usernames and their hashed passwords (where `*`
is the name of the app, eg. [invidious](../invidious) uses `INVIDIOUS_HTTP_AUTH`
and [nodered](../nodered) uses `NODERED_HTTP_AUTH`).

You must generate an [htpasswd](https://man.archlinux.org/man/htpasswd.1)
formatted string that contains the desired username and a hashed password, and
then paste it into your `.env` file.

This project contains a program to generate usernames and randomized passwords
in the format needed for the `.env` files.

## Usage

From any project directory, use the `Makefile` target:

```
make htpasswd
```

The program will prompt for you to enter a username. A randomly generated
password and all the credential forms will be printed to stdout:

 * `Username:` and `Plain text password:`. You will need these to log into the
   web page.
 * `Hashed user/password (copy this to .env):`. This is the Traefik formatted
   config you need to copy into your `.env` file as your `*_HTTP_AUTH` variable
   (where `*` is the name of the app. Each app's `.env-dist` has an example, so
   just replace the example.)
 * `Url encoded:` you can use this to share a URL with the username and password
   baked in. Just replace the `example.com/...` part with your actual domain
   name and path.
