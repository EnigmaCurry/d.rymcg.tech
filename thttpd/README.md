# thttpd

[thttpd](https://www.acme.com/software/thttpd/) is "a simple, small, portable,
fast, and secure HTTP server."

## Configure

Run `make config`

Answer the questions for these variables:

 * `THTTPD_TRAEFIK_HOST` - The domain name for the website.

Put your static website source files into the `./static` directory and
they will be copied into the initial volume created. You can also use
the [sftp](../sftp) service, and upload new files into the shared
volume (`thttpd_files` or `thttpd_${INSTANCE}_files`).

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

Run `make install`

## Open the site

Run `make open`
