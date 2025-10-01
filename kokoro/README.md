# Kokoro Web

[Kokoro Web](https://github.com/eduardolat/kokoro-web) is a powerful,
browser-based AI voice generator that lets you create natural-sounding
voices.

It includes an OpenAI-compatible API that works as a drop-in
replacement for applications using OpenAI's text-to-speech API.

To access the API, append "/api/v1" to the URL.
Example: `KOKORO_TRAEFIK_HOST=kokoro.example.com`
 * `https://kokoro.example.com/api/v1` to access the Swagger UI
 *  `https://kokoro.example.com/api/v1/audio/models` to hit that
particular API endpoint

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

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

This completely removes the container.

## CLI scripts

Check out [tts-script](tts-script)
