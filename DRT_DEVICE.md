# drt device mode

drt device mode runs an unlocked [drt](WORKSTATION_CONTAINER.md)
session as a long-lived device that an AI agent operates. You unlock
it once. After that, the agent runs commands in it one at a time,
saves its own config changes, and the device locks itself when its
lease runs out.

The split is:

- **You hold the key.** Only you can unlock the device, with your
  AGE passphrase, FIDO2 touch, or key file. The agent never sees the
  key or the passphrase.
- **The agent operates it.** While the device is unlocked, the agent
  has the same power you have in a `drt` shell. It should ask you in
  conversation before anything destructive. To have Claude Code
  enforce that, see [Permission rules](#permission-rules).
- **The device locks itself.** It saves any unsaved changes and stops
  when the lease ends, after an idle timeout, on `drt --lock`, or when
  you press Ctrl-C in its console.

This lets you drive a server from your phone through an agent (for
example with Claude Code Remote Control) while you're away from your
desk. Unlock the device before you leave.

## Unlock a device

At your workstation:

```bash
drt --serve myserver                  # default lease 12h, idle lock after 2h
drt --serve myserver --lease 3d --idle 0   # 3 days, never idle-locks
```

Durations are seconds or a number with a unit: `90s`, `30m`, `12h`,
`2d`. `0` turns that limit off.

drt decrypts the config as usual, then shows the device console:

```
## drt device is UNLOCKED: myserver
##   lease:        12h00m (until 2026-11-16 07:00 UTC)
##   idle timeout: 2h00m
...
2026-11-15T19:00:01Z unlocked (lease 12h, idle 2h)
2026-11-15T19:00:12Z exec: d.rymcg.tech make whoami status
2026-11-15T19:00:13Z exit 0: d.rymcg.tech make whoami status
```

The console lists every command the agent runs and its exit code.
The command output goes to the agent, not to the console.

- **Ctrl-C** saves and locks the device.
- **Ctrl-p Ctrl-q** detaches from the console and leaves the device
  running.

A context can run as a device or as an interactive `drt myserver`
shell, but not both at the same time.

## Drive a device

These commands run on the host, the same as the agent runs them:

```bash
drt --exec myserver -- d.rymcg.tech make whoami status   # run one command
drt --exec myserver -- d make whoami status              # `d` works too
drt --exec myserver -- bash -c 'docker ps | grep traefik' # pipes need a shell
drt --status myserver   # lease and idle time left, number of unsaved keys
drt --save myserver     # save changes now, then git commit
drt --lock myserver     # save, shut down, then git commit
drt --exec myserver -- drt-device diff   # names of unsaved keys, no values
```

The agent calls the same `drt` shell function you use. If the agent's
shell doesn't load your `~/.bashrc`, put `drt` on your `PATH` as a
file instead:

```bash
podman run --rm --pull=never --net=none "${DRT_IMAGE}" drt --extract > ~/.local/bin/drt
chmod +x ~/.local/bin/drt
```

`--exec` runs the command with the arguments exactly as given,
without a shell, and returns its exit code. If no device is running
for the context, it exits with code 3.

## Saving

There is no save-on-exit prompt in device mode. Changes are saved:

- when the agent runs `drt --save`,
- when the device locks, for any reason.

`--save` and `--lock` print only the names of changed keys, never
their values:

```
## Saved changes to the SOPS config:
~ WHOAMI_TRAEFIK_HOST
+ WHOAMI_IMAGE
```

If `~/.config/d.rymcg.tech` is a git repo (see `drt --git-init`),
`--save` and `--lock` commit the changes and push them to the first
remote. When there's no terminal to ask, the push happens
automatically, which matches the interactive default of yes. Set
`DRT_GIT_PUSH=false` to commit without pushing.

For a FIDO2 key, a save can't wait for a touch, because nobody may be
at the desk. The device re-encrypts the whole file to your public key
instead of re-encrypting only the changed values. The file is
encrypted the same way, but the git diff shows every value as
changed.

## Permission rules

The device doesn't decide what the agent may run; your agent's own
permission system does. Every action is a separate `drt` command with
its arguments visible, so Claude Code permission rules can match
them. Allow the read-only commands and leave everything else to ask.
A command that isn't allowed shows a permission prompt, on your phone
too when you use Remote Control.

An example `.claude/settings.json` for a context named `myserver`:

```json
{
  "permissions": {
    "allow": [
      "Bash(drt --status myserver)",
      "Bash(drt --exec myserver -- drt-device diff)",
      "Bash(drt --exec myserver -- d.rymcg.tech status:*)",
      "Bash(drt --exec myserver -- d.rymcg.tech make * status:*)",
      "Bash(drt --exec myserver -- d.rymcg.tech make * logs-out:*)",
      "Bash(drt --exec myserver -- d.rymcg.tech make * config-render:*)",
      "Bash(drt --exec myserver -- d.rymcg.tech make * dotenv_get:*)",
      "Bash(drt --exec myserver -- docker ps:*)",
      "Bash(drt --save myserver)"
    ],
    "deny": [
      "Bash(drt --serve:*)"
    ]
  }
}
```

`install`, `reconfigure`, `uninstall`, `destroy` and anything run
through `bash -c` aren't on the list, so they ask every time. Move
`install` and `reconfigure` to `allow` if you trust the agent with
them. Keep `destroy` and `bash -c` on ask: once an agent has a shell
inside the device, it can do anything the device can.

## Security

- While a device is unlocked, its secrets are decrypted inside the
  container. Any process running as your user can read them through
  `podman exec` or `podman cp`, the same as in an interactive `drt`
  session. Run devices only on a workstation you trust.
- An agent with `bash -c` access can print any secret, for example
  with `cat` on an `.env` file. Hiding values from `--save` and
  `drt-device diff` output only keeps them out of chat transcripts by
  default. It doesn't stop the agent from reading them.
- Use short leases. When you're done, run `drt --lock myserver`.
- The agent can't unlock a device, so it can't use your config after
  the device locks. Don't type your passphrase into the agent's chat.
  That would defeat the encryption.

## How it works

`drt --serve` starts the usual drt container with `drt-device serve`
as its main process instead of a shell. The entrypoint sets up SSH,
the Docker context and the project `.env` files as it always does.
`drt-device serve` then saves that environment to a file for later
`podman exec` calls, records the baseline used for diffs, and runs
the lease timer.

`drt --exec` runs `podman exec drt-<context> drt-device exec ...`.
Each command loads the saved environment, resets the idle timer,
writes a line to the console log, and runs.

Saving uses the same code as an interactive session's
save-on-exit (`_container/drt-save.sh`) and the same root helper in
`entrypoint.sh`, which is the only process that can write the
encrypted file on the host.
