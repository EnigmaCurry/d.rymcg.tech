# Docker workstation on Windows (WSL) with d.rymcg.tech

This article is a step-by-step tutorial for setting up a
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) Docker
workstation on a Windows (11) host via the Windows Subsystem for Linux
(WSL).

## Install WSL

### Open Powershell

In the PowerShell window, run:

```powershell
wsl --install
```

* Follow the prompts to install WSL.
* Reboot.

## Install Debian

* Open the Microsoft Store, and search for `Debian` and install it.
* Open the `Debian` app.
* Choose a new Linux username and password.

## Install packages

In the Debian terminal, run:

```bash
sudo apt update
sudo apt install bash build-essential gettext git openssl apache2-utils \
                 xdg-utils jq sshfs wireguard curl inotify-tools w3m \
                 moreutils keychain
```

Note: `sudo` may ask you to enter your *Linux* user's password.

## Install Docker client tools

This guide **does not recommend** installing Docker Desktop. Firstly,
Docker Desktop is not open source. Secondly, we don't need nor want
any Docker Engine (VM) running on our workstations (we only need the
CLI `docker` client tools, since we only need to control our *remote*
Docker servers). That said, if you have already installed Docker
Desktop, it will probably work, so in that case you may skip the rest
of this section.

To install the open source Docker tools, run:

```bash
curl -fsSL https://get.docker.com | sudo bash
```

Ignore the warning this script generates urging you to install Docker
Desktop. Just wait 20 seconds for the warning to time out and the
script will then start installing the required packages.

To explicitly disable the Docker Engine service, run:

```bash
systemctl disable --now docker.service
systemctl disable --now docker.socket
```

## Clone the d.rymcg.tech git repository

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ~/git/vendor/enigmacurry/d.rymcg.tech

cd ~/git/vendor/enigmacurry/d.rymcg.tech
```

## Configure Bash

Configure your `~/.bashrc` for d.rymcg.tech:

```
cat <<'EOF' >> ~/.bashrc

export EDITOR=code

## Load SSH key into keychain ssh-agent:
eval "$(keychain --quiet --eval --agents ssh id_ed25519)"

## Configure d.rymcg.tech:
export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"
__d.rymcg.tech_cli_alias d
EOF
```

Close the Debian window and re-launch it.

## Configure SSH key

Create an SSH key:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

Enter a password to unlock the key (optional).

Close Debian WSL and re-launch it. 

On first boot, Debian WSL should ask you for your key's password (if
any). The decrypted key is cached indefinitely inside the running
ssh-agent process. If the Debian WSL reboots, you will need to
re-enter your password again.

## Install VS Code

Open the Microsoft Store and search for `Visual Studio Code` and
install it.

Close Debian WSL and re-launch it.

You can now use the `code` command inside Debian and it will launch
your VS code editor on Windows.

Open the d.rymcg.tech directory with VS code:

```
code ~/git/vendor/enigmacurry/d.rymcg.tech
```

The first time you do this, code will ask you to confirm trust
`wsl.localhost`. Check `Permanently allow host wsl.localhost` and
click `Allow`.
