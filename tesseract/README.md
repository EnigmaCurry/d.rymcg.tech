# Tesseract

[Tesseract](https://github.com/asimons04/tesseract) is a Sublinks/Lemmy
client designed for media-rich feeds and content. It can act as a front-end
for Lemmy instances.

## Config

```
make config
```

This will ask you to enter the domain name to use, as well as the base URL
of the Lemmy instance you want Tesseract to act as the front-end for.

It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container and volumes.
