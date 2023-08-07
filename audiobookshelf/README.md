# Audiobookshelf

[Audiobookshelf](https://github.com/advplyr/audiobookshelf)
is a self-hosted audiobook and podcast server.

## Configure

Run:

```
make config
```

## Install

Run:

```
make install
```

## Open in your web browser

Run:

```
make open
```

After you `make open`, log into Audiobookshelf as the
admin, go to config -> users, click on your account, copy the API Key and
paste it into `HOMEPAGE_AUDIOBOOKSHELF_API_KEY` in your `.env_{DOCKER_CONTEXT}` file,
then run `make install` again. This will allow Audiobookshelf to be
automatically discovered by Homepage, if you use that service.