# Docker workstation on Linux with d.rymcg.tech

This article is a step-by-step tutorial for setting up a
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) Docker
workstation on a Linux host.

## Install packages

For Debian (and Ubuntu) workstations, run:

```bash
sudo apt update
sudo apt install bash build-essential gettext git openssl apache2-utils \
                 xdg-utils jq sshfs wireguard curl inotify-tools w3m \
                 moreutils keychain ipcalc-ng
                 
curl -fsSL https://get.docker.com | sudo bash
```

For Fedora workstations, run:

```
sudo dnf update
sudo dnf install bash gettext openssl git xdg-utils jq sshfs curl inotify-tools \
                 httpd-tools make wireguard-tools w3m moreutils ipcalc

curl -fsSL https://get.docker.com | sudo bash
```

For Arch Linux workstations, run:

```
sudo pacman -Syu
sudo pacman -S bash base-devel gettext git openssl apache xdg-utils jq sshfs \
               wireguard-tools curl inotify-tools w3m moreutils ipv6calc

sudo pacman -S docker

## You may also need to install "ipcalc-redhat" from the AUR.
##   sudo yay -S ipcalc-redhat
```

## Disable Docker Engine on your workstation

Your workstation will only be used to control other remote Docker
servers, therefore you should disable the Docker Engine service on
your workstation:

```bash
sudo systemctl disable --now docker.service
sudo systemctl disable --now docker.socket
```

## Clone the d.rymcg.tech git repository

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ~/git/vendor/enigmacurry/d.rymcg.tech

cd ~/git/vendor/enigmacurry/d.rymcg.tech
```

Note: You may change the path if you wish, but it is recommended that
you do not. `~/git/vendor/enigmacurry/d.rymcg.tech` is a vendor
neutral path that other *external* projects may reference, but by
convention only.

## Configure Bash

Configure Bash for d.rymcg.tech (`~/.bashrc`). 

Copy and paste this entire block into your terminal to run as one
command:

```
cat <<'EOF' >> ~/.bashrc

## Load SSH key into keychain ssh-agent:
eval "$(keychain --quiet --eval --agents ssh id_ed25519)"

## Configure d.rymcg.tech:
export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"
__d.rymcg.tech_cli_alias d
EOF
```

Close the terminal and re-launch it.

## Configure Bash aliases

You may wish to setup extra Bash aliases (alternatives to `d`) to
control specific Docker contexts, or external project directories.

```
## Show example aliases:
d aliases
```

This will print an *example* set of aliases you can choose from. You
should evaluate what aliases make sense to you and copy them into
`~/.bashrc` yourself.

## Configure SSH key

Create an SSH key:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

Enter a password to unlock the key (optional).

Close the terminal and re-launch it. 

The next time you open the terminal, it should ask you for your key's
password (if any). The decrypted key is cached indefinitely inside the
running ssh-agent process, so it will only ask once. If the computer
reboots, you will need to re-enter your password again.

