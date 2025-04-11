# Commentario

[Commentario](https://gitlab.com/comentario/comentario) is a comment
platform for your websites.

## Deploy postfix-relay

To support outgoing email, install [postfix-relay](../postfix-relay)
on the same Docker server. Commentario will connect to the same Docker
network: `postfix-relay_default`.

## Pull Docker image

The commentario image hosted on gitlab may fail to install via
docker-compose. The workaround is to pull and tag the image manually:

```
docker pull registry.gitlab.com/comentario/comentario
docker tag registry.gitlab.com/comentario/comentario localhost/commentario
```

## Config

```
make config
```

## Install

```
make install
```

## Create superuser

Open the web interface:

```
make open
```

Your web browser should automatically open the interface.

*IMPORTANT:* /Immediately/ register a new user account. The first user
that registers automatically becomes the superuser.


## Adding comments to a web page

In the commentario admin console, add the domain name of the page you
wish to add comments to. Only domains that have been configured are
allowed to render comments.

Add the following HTML block to any webpage. Modify the domain name in
the script src tag to match your commentario deployment URL
(`COMMENTARIO_TRAEFIK_HOST`). The CSS style is optional, but it will
ensure that it renders correctly with a dark background:

```
<script defer src="https://commentario.example.com/comentario.js"></script>
<comentario-comments></comentario-comments>

<style>
  comentario-comments .comentario-root {
  background-color: #1a1a1a !important; /* Dark background */
  color: #f0f0f0 !important;           /* Light text */
}

comentario-comments .comentario-root * {
  color: inherit !important;
  background-color: transparent !important;
  border-color: #444 !important;
}

/* Optional: override specific muted or themed classes */
.comentario-text-muted {
  color: #aaa !important;
}

.comentario-bg-anonymous,
.comentario-bg-6,
.comentario-bg-29 {
  background-color: #333 !important;
}

/* Optional: style buttons and toolbars for visibility */
.comentario-btn {
  background-color: #333 !important;
  color: #fff !important;
  border: 1px solid #555 !important;
}

.comentario-btn:hover {
  background-color: #444 !important;
}
</style>

```
