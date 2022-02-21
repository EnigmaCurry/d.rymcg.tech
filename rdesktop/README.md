# rdesktop

This is based upon the
[linuxserver/docker-baseimage-rdesktop-web](https://github.com/linuxserver/docker-baseimage-rdesktop-web),
which lets you run an Xorg (X11) remote desktop session in your web browser.

This configuration is based upon the Arch Linux variant, installs XFCE4 and
customizes `urxvt` and a few other things.

## Setup

Run `make config`

You need to choose a username and a strong password to protect the remote
desktop.

Enter the list of extra programs you want to install (eg. `emacs python`).

## Startup

Run `make install`

Open the browser with `make open`.

## Statefulness

You must not rely upon the state of the root filesystem of the container, if you
destroy the container, all of your changes can be gone in a flash. However, the
home directory `/config` is stored in a volume `rdesktop_config`, and this will
persist if you recreate the container. Do not install packages directly with
pacman, instead add them to the list of `PROGRAMS` in your .env file, and then
run `make install` again (this will rebuild and restart the container).

