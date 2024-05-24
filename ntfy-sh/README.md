# ntfy.sh

[ntfy.sh](https://ntfy.sh) is a simple HTTP-based pub-sub notification
service. Send and receive push notifications from any device or
service. Integrate with [UnifiedPush](https://unifiedpush.org/) as a
replacement for Google's Firebase Cloud Messaging (FCM). With ntfy
installed on your Android phone, you can have a single websocket-like
connection to your ntfy instance, and receive notifications for all
your android apps that support UnifiedPush. This offers more efficient
usage of network and battery resources.

## Config

```
make config
```

## Install

```
make install
```

## Open app in browser

```
make open
```

## Manage users

[Follow the directions](https://ntfy.sh/docs/config/#users-and-roles)
for running the command line `ntfy user` and `ntfy access` commands.
You can open the container shell:

```
make shell
```

Then you can run any `ntfy` command.

You can also use the predefined make targets to interactively manage
your users:

```
make user             # Create a new user
make access           # Show all users and privileges
make grant-read-only  # Grant user read-only access to a single channel
make grant-read-write # Grant user read-write access to a single channel
make grant-write-only # Grant user write-only access to a single channel
make grant-anonymous-read-only # Grant anonymous read-only access to a single channel
make grant-anonymous-read-write # Grant anonymous read-write access to a single channel
make grant-anonymous-write-only # Grant anonymous write-only access to a single channel
make user-remove      # Remove one user account
make user-reset       # Reset all privileges of one user
make reset-all-users  # Reset all privileges for all users
make delete-all-users # Delete all users and permissions and reboot container
```
