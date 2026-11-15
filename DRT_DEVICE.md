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

There are three ways for an agent to drive a device. From most to
least locked down:

1. **MCP tools** (`drt --mcp CONTEXT`): one typed tool per action
   (`status`, `install`, `destroy`, ...). Permissions are set per tool.
   See [MCP server](#mcp-server).
2. **Request verbs** (`drt --exec CONTEXT -- request VERB ...`): the
   same actions as shell commands, with JSON results. See
   [Request verbs](#request-verbs).
3. **Raw commands** (`drt --exec CONTEXT -- CMD ...`): anything at
   all, with the full power of a `drt` shell.

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

The agent calls the same `drt` shell function you use. Agent shells
often don't load your `~/.bashrc`, so put a small launcher on your
`PATH` that loads the function from the image on every run:

```bash
cat > ~/.local/bin/drt <<'EOF'
#!/usr/bin/env bash
## Loads drt from the image on every run, so it never goes stale.
export DRT_IMAGE=ghcr.io/enigmacurry/d-rymcg-tech:latest
source <(podman run --rm --pull=never --net=none --entrypoint cat "${DRT_IMAGE}" \
  /home/user/git/vendor/enigmacurry/d.rymcg.tech/_container/drt.bashrc)
drt "$@"
EOF
chmod +x ~/.local/bin/drt
```

Set `DRT_IMAGE` in it to the image you use: the same value as in your
`~/.bashrc`, or `localhost/d-rymcg-tech:latest` if you build your own.
The launcher sets it outright, because an agent's environment may
carry a different value. Don't copy the script out with
`drt --extract`: the copy goes stale when you pull or build a new
image.

`--exec` runs the command with the arguments exactly as given,
without a shell, and returns its exit code. If no device is running
for the context, it exits with code 3.

## Request verbs

`request` runs one d.rymcg.tech action, checks its arguments first,
and prints a JSON result:

```bash
drt --exec myserver -- request list                       # projects
drt --exec myserver -- request status whoami              # containers, as JSON
drt --exec myserver -- request config-dist whoami         # never overwrites
drt --exec myserver -- request reconfigure whoami WHOAMI_TRAEFIK_HOST=whoami.example.com
drt --exec myserver -- request get root ROOT_DOMAIN       # context-wide config
drt --exec myserver -- request install whoami timeout=120
drt --exec myserver -- request destroy whoami instance=test
```

| Verb | Arguments |
| --- | --- |
| `list` | |
| `instances` | `PROJECT` |
| `status` | `[PROJECT] [instance=]` (all projects if omitted) |
| `logs` | `PROJECT [service=] [tail=N] [instance=]` |
| `get` | `PROJECT\|root VAR [instance=]` |
| `config-render` | `PROJECT [instance=]` |
| `config-dist` | `PROJECT [instance=]` |
| `reconfigure` | `PROJECT\|root VAR=VALUE... [instance=]` |
| `install`, `reinstall`, `wait` | `PROJECT [instance=] [timeout=SEC]` |
| `start`, `stop`, `restart` | `PROJECT [service=] [instance=]` |
| `uninstall`, `destroy` | `PROJECT [instance=]` |

Lowercase `key=value` words are options. Uppercase `VAR=VALUE` words
are config variables. The project `root` means the context-wide config
(`.env_CONTEXT`).

Before running anything, `request` refuses these, exiting with code 64
and an `error` message:

- an unknown project, verb, option, or malformed name;
- `config-dist` when the instance config already exists (use
  `reconfigure` instead, per AGENTS.md);
- `reconfigure` of a variable that isn't in the file, or of an instance
  that isn't configured yet;
- lifecycle verbs on an instance that isn't configured.

`uninstall`, `reinstall` and `destroy` run without a confirmation
prompt. The agent's permission system is what asks you (see below).
`<PREFIX>_INSTANCE_PROTECTION=true` still blocks `uninstall` and
`destroy`.

Long output is cut to its last 12,000 characters, and logs to the
last 200 lines (`tail=N` to change).

## MCP server

`drt --mcp myserver` is a stdio [MCP](https://modelcontextprotocol.io)
server with one tool per action. Register it with Claude Code once:

```bash
claude mcp add drt-myserver -- drt --mcp myserver
```

That needs the `drt` launcher on your `PATH` (see
[Drive a device](#drive-a-device)), because Claude Code doesn't start
MCP servers through your `~/.bashrc`.

The tools:

| Tool | Does |
| --- | --- |
| `device_status`, `device_diff` | lease, idle timer, unsaved key names |
| `save`, `lock` | save (then git commit on the host); save and shut down |
| `list_projects`, `list_instances`, `status`, `logs`, `get_config`, `config_render` | read only |
| `config_dist`, `reconfigure` | change config inside the device |
| `install`, `reinstall`, `start`, `stop`, `restart`, `wait` | lifecycle |
| `uninstall`, `destroy` | remove containers; destroy also deletes volumes |
| `run` | any command (`argv` list), the raw-command escape hatch |

Each tool call runs a request verb (or `drt-device` command) through
the device, so it shows in the device console and resets the idle
timer.

The server keeps running while the device is locked. Tool calls then
return an error telling the agent the device is locked and that only
you can unlock it. When you `drt --serve` again, the same MCP server
picks the device back up without reconnecting.

### Example prompts

Ask in plain language and name the context. The agent picks the tools.
These examples use a context named `myserver`.

Looking around (read-only tools, nothing changes):

- "What's running on myserver?"
- "Is copyparty on myserver healthy? Show me its last 100 log lines."
- "What domain is whoami on, and what's the root domain?"
- "How long until the myserver device locks? Are there unsaved
  changes?"

Installing and configuring:

- "Install forgejo on myserver at git.myserver.example.com, HTTPS
  only." The agent checks that no config exists, then runs
  `config_dist`, `reconfigure`, `save`, `install` and `wait`.
- "Set up a second whoami instance called test, check that it's
  healthy, then remove it."
- "Only allow my home IP, 203.0.113.7, to reach whoami. Show me the
  rendered config before you install it."
- "Upgrade whoami to the latest image tag." This changes the image
  variable and runs `install`.
- "Restart the copyparty container."

Saving and locking:

- "Save the config." This encrypts the changes, then commits and pushes
  them if the config dir is a git repo.
- "I'm done for today. Save and lock the device."

Raw commands through `run` (these always need your approval, see
[Permission rules](#permission-rules)):

- "How much disk space is left on myserver?"
- "Prune unused Docker images on myserver."
- "Run `d.rymcg.tech audit` and summarize the findings."

The agent asks you in conversation before anything destructive, such
as `uninstall`, `destroy`, a `reinstall` of something others depend
on, or a change to an existing app's routing, TLS or auth. Answer in
chat, or in the permission prompt for the tool. Things it can't do for
you: unlock the device, run interactive wizards such as `make config`,
change DNS that drt has no credentials for, or finish an app's
web-only setup. For those, it tells you what to do.

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

The push uses your ssh-agent unless the config repo has its own key.
If your agent's key is a FIDO2 key, the push waits for a touch that
nobody gives, and then fails. Run `drt --git-deploy-key` once at
your desk to give the repo its own key (see
[Use a deploy key](WORKSTATION_CONTAINER.md#use-a-deploy-key)).

For a FIDO2 key, a save can't wait for a touch, because nobody may be
at the desk. The device re-encrypts the whole file to your public key
instead of re-encrypting only the changed values. The file is
encrypted the same way, but the git diff shows every value as
changed.

## Permission rules

The device doesn't decide what the agent may run; your agent's own
permission system does. Allow the read-only actions and leave
everything else to ask. An action that isn't allowed shows a
permission prompt, on your phone too when you use Remote Control.
That prompt is how the agent "asks you in conversation", and Claude
Code enforces it whatever the agent does.

With the MCP server, set permissions per tool. An example
`.claude/settings.json` for a context named `myserver`:

```json
{
  "permissions": {
    "allow": [
      "mcp__drt-myserver__device_status",
      "mcp__drt-myserver__device_diff",
      "mcp__drt-myserver__list_projects",
      "mcp__drt-myserver__list_instances",
      "mcp__drt-myserver__status",
      "mcp__drt-myserver__logs",
      "mcp__drt-myserver__get_config",
      "mcp__drt-myserver__config_render",
      "mcp__drt-myserver__wait",
      "mcp__drt-myserver__save"
    ],
    "deny": [
      "Bash(drt --serve:*)",
      "Bash(drt --exec myserver:*)"
    ]
  }
}
```

Every other tool asks first: `config_dist`, `reconfigure`, `install`,
`restart`, `uninstall`, `destroy`, `run`, and so on. Move the ones you
trust to `allow`. The `deny` on `drt --exec` keeps the agent on the
MCP tools, so it can't get around a tool's prompt through Bash. Keep
`run` on ask: it's a raw command inside the device, which can do
anything the device can.

Without MCP, the same idea works with Bash rules on request verbs:

```json
{
  "permissions": {
    "allow": [
      "Bash(drt --status myserver)",
      "Bash(drt --save myserver)",
      "Bash(drt --exec myserver -- drt-device diff)",
      "Bash(drt --exec myserver -- request list)",
      "Bash(drt --exec myserver -- request instances:*)",
      "Bash(drt --exec myserver -- request status:*)",
      "Bash(drt --exec myserver -- request logs:*)",
      "Bash(drt --exec myserver -- request get:*)",
      "Bash(drt --exec myserver -- request config-render:*)"
    ],
    "deny": [
      "Bash(drt --serve:*)"
    ]
  }
}
```

Bash rules match text, so they're weaker than per-tool permissions.
A raw `drt --exec myserver -- bash -c ...` isn't allowed by any of
these rules and asks every time, but read the command in the prompt
before you approve it.

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
writes a line to the console log, and runs. `request` is
`_container/drt_request.py`, which checks its arguments and then runs
the matching `d.rymcg.tech make` target.

`drt --mcp` reads JSON-RPC lines from the agent and sends each one to
`drt-device mcp` (`_container/drt_mcp.py`) in the device. That turns a
tool call into a `drt-device exec request ...` call. While the device
is locked, a throwaway `--net=none` container answers instead. The
device can't reach your config repo, so after a `save` or `lock` tool
call the host side runs the git commit.

Saving uses the same code as an interactive session's
save-on-exit (`_container/drt-save.sh`) and the same root helper in
`entrypoint.sh`, which is the only process that can write the
encrypted file on the host.
