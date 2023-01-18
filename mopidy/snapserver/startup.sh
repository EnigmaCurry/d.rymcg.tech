#!/usr/bin/env sh

dbus-daemon --system
avahi-daemon --no-chroot &
/usr/bin/snapserver $EXTRA_ARGS
