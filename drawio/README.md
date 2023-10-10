# drawio

[drawio](https://github.com/jgraph/drawio) is an open source browser
based diagram tool. This deployment uses the
[jgraph/docker-drawio](https://github.com/jgraph/docker-drawio) docker
image.

Note: this image is not working on arm64.

## Configure

```
make config
```

This will ask you to enter the domain name to use, and whether or not
you want to configure a username/password via HTTP Basic Authentication.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

It will also ask if you want to use OpenID/OAuth2 authentication. 
Using OpenID/OAuth2 will require a login to access your app, but it will not
affect what a successfully logged-in person can do in your app. If your app has
a built-in authorization mechanism that can check for the user header that
traefik-forward-auth sends, then your app can limit what the logged-in person
can do in the app. But if your app can't check the user header, or if your app
doesn't have built-in authorization at all, then any person with an account
on your Gitea server can log into your app and have full acces

## Install

```
make install
```


```
make open
```
