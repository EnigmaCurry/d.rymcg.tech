# tty-clock

[tty-clock](https://github.com/xorg62/tty-clock) is a terminal clock app.

Build the image using UTC timezone:

```
make build
```

At buildtime, burn your preferred `TIMEZONE` into the image:

```
TIMEZONE=America/Los_Angeles make build
```

You can also override the default at runtime:

```
TIMEZONE=America/New_York make clock
```

You can run with podman instead of docker:

```
DOCKER=podman TIMEZONE=America/New_York make clock
```

## Bash alias

```
alias clock='DOCKER=podman TIMEZONE=America/Los_Angeles make -C ~/git/vendor/enigmacurry/d.rymcg.tech/_terminal/tty-clock clock'
```
