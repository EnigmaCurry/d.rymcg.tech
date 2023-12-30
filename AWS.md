# Docker on AWS EC2

You can use [AWS](https://aws.amazon.com/ec2/) to host a docker server
online.

Note: this doc is meant to be followed linearly, but it leaves out a
lot of important bits. Read the main [d.rymcg.tech README](README.md)
to fill in those gaps!

## Create SSH keypair

On your workstation, create a new keypair named after your deployment:

```
## Create a new ED25519 keypair, for example, naming it aws-docker-dev:
ssh-keygen -t ed25519 -f ~/.ssh/aws-docker-dev
```

For documentation purposes, we will choose not to set a password,
leaving the keyfile unencrypted. In practice, you should set a
password to encrypt it, and you should use the `ssh-agent` to
temporarily load your key into memory (then you only need to enter
your password once when you login.)

Upload your public key to AWS:

 * Go to the EC2 dashboard.
 * Under `Network & Security`, click `Key Pairs`.
 * Under the `Actions` button, there is a dropdown, select `Import key pair`.
 * Name the keypair after the name of your workstation computer.
 * Paste the contents of the file `~/.ssh/aws-docker-dev.pub`, which
   is your public key, and it starts with `ssh-ed25519 .....`.
 * Click `Import key pair`

## Create an EC2 instance

 * Go to the EC2 dashboard.
 * Under `Instances` click `Instances`.
 * Click the `Launch Instances` button.
 * Configure the instance with the following settings:
 
   * Name: this is a unique name for your server (eg. `docker-dev`).
     It should include the stage name for your instance, eg. `dev` or
     `prod`. Including the literal word `docker` is useful to indicate
     its purpose, but you might want to just call it `dev` instead if
     its otherwise obvious to do so. If you require multiple servers
     for the same stage, you would name them with a `dev-` or `prod-`
     prefix, followed by a unique name.

   * Image: Choose the AMI for Debian 12+ x86_64.
   
   * Instance type: choose whatever instance size you need for your
     deployment, these instructions are tested on `t2.small`, which
     has 2GB of RAM.
     
   * Key pair: Select your SSH key that you previously uploaded

   * Network: leave the default settings, to create a new security
     group. Check all of the following boxes to allow public traffic:
     
     * Allow SSH traffic from Anywhere, or you can lock it down to a
       specific IP range. This is for administration only.
     
     * Allow HTTPS from Anywhere.
     
     * Allow HTTP from Anywhere.
     
   * Configure two storage volumes:
   
     * One for the root volume: 10GB.
     
     * A second one for the Docker images and volumes: 50GB.

   * Verify everything is correct, and click the `Launch Instance` button.

## Create an elastic IP address

Create an elastic IP address for your EC2 instance, so that you can
keep the same IP address, even if you need to destroy and recreate
your EC2 instance:

 * Login to the AWS console.
 * Go to the EC2 dashboard.
 * Under `Network & Security`, click `Elastic IPs`.
 * Click the `Allocate Elastic IP address` button.
 * Use the default settings, and click `Allocate`.
 * Associate the elastic IP address to the EC2 instance you created.

## Create the DNS records for the EC2 instance

 * Login to the route53 dashboard.
 * Find the domain listed on the Hosted zones page, and click on it.
 * Click `Create Record`.
   * Enter the `Record name`: `docker-dev`
   * Choose the `Record type`: `A`
   * Enter the value: Paste the public IPv4 address of your elastic IP address.
   * Click the `Add another record` button.
   * Enter the second `Record name`: `*.docker-dev`
   * Click the `Create Records` button.

## Create a SSH config file on your workstation

On your workstation, edit or create the file `~/.ssh/config`. Put the
following new config for your EC2 instance:

```
Host docker-dev
     Hostname docker-dev.example.com
     User admin
     IdentityFile ~/.ssh/aws-docker-dev
```

## Test logging into the server from your workstation

Login using the config name:

```
ssh docker-dev
```

The first time you login, you must verify the server's key fingerprint, for example:

```
The authenticity of host '3.82.242.83 (3.82.242.83)' can't be established.
ED25519 key fingerprint is SHA256:vxFMXJHiV42S7Hje7zeTzNX6k7WBzBIajWGY1CraS00.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? 
```

You must type the literal response `yes` and press Enter, to accept
the key. From now on, you won't see this message for this server,
because it will be marked as trusted in `~/.ssh/known_hosts`.

You should now have successfully connected to the instance, as the
`admin` user, and the shell is open for it:

```
# You should see the prompt now for the remote instance:
admin@ip-172-31-87-15:~$
```

## Mount the EBS volumes

The root volume is pre-provisioned, however the other volume that you
created needs to be formatted and mounted.

Run `sudo fdisk -l` to list all the volumes:

```
admin@ip-172-31-87-15:~$ sudo fdisk -l
Disk /dev/xvda: 10 GiB, 10737418240 bytes, 20971520 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 551AAE53-DCFD-5D44-A0BF-A5970118A66D

Device       Start      End  Sectors  Size Type
/dev/xvda1  262144 20971486 20709343  9.9G Linux filesystem
/dev/xvda14   2048     8191     6144    3M BIOS boot
/dev/xvda15   8192   262143   253952  124M EFI System

Partition table entries are not in disk order.


Disk /dev/xvdb: 50 GiB, 53687091200 bytes, 104857600 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
```

Here you see that the 10GB root volume is on device `/dev/xvda`, and
it contains the root partions. The other 50GB volume is on device
`/dev/xvdb`, but it has no partitions defined.

In fact, you do not need to partition the second device, you will
format it and use it directly. Create the ext4 filesystem on
`/dev/xvdb`:

```
sudo mkfs.ext4 /dev/xvdb
```

Create the directory where you want to mount the volume. For storing
Docker data, create the directory `/var/lib/docker`:

```
sudo mkdir -p /var/lib/docker
```

Find the unique identifier (UUID) of the disk:

```
sudo blkid | grep /dev/xvdb
```

For example, this might return something that looks like:

```
# Example blkid output:
/dev/xvdb: UUID="14416f5d-5152-4d89-bfdd-966be4dd8891" BLOCK_SIZE="4096" TYPE="ext4"
```

Copy the UUID value printed.

Create a new entry in `/etc/fstab` to automatically mount the
filesystem:

```
## Make sure to use your actual disk UUID not this example:
echo "UUID=14416f5d-5152-4d89-bfdd-966be4dd8891 /var/lib/docker ext4 defaults 0 1" \
  | sudo tee -a /etc/fstab
```

Now mount the filesystem (or reboot the instance to have it auto-mounted)

```
sudo mount /var/lib/docker
```

## Install Docker Engine on the EC2 instance

You can follow the [official instructions to install Docker Engine on
Debian](https://docs.docker.com/engine/install/debian/), but the
essential bits are copied here:

```
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Add the admin user to the Docker group

By default, only the `root` user is allowed to run Docker containers,
but since you are logging in with the `admin` user, you need this user
to the `docker` group, to give it the privilege of running `docker`:

```
sudo gpasswd -a admin docker
```

You need to log out and log back in to reload your groups. Once logged
back in, test that you can successfully run docker commands:

```
docker ps
```

This normally prints out all the running containers, but since you
haven't created any, you should just see this line instead:

```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

As long as you see that text output, you have successfully installed
and configured Docker.

## Log out of the EC2 instance, and never log back in!

Now you can quit the remote shell (press Ctrl-D or type `exit`), and
you should never need to log back in to the console unless theres a
problem that you need to fix by hand. Under normal circumstances, you
will no longer need to log in remotely, and you will manage your
instance from your workstation instead.

## Create Docker context on your workstation

Make sure you have install the `docker` client on your workstation. On
WSL2 or MacOS, you can use Docker Desktop. 

Create the new remote context for your EC2 instance. This uses the
name of the server, the same name as used in your SSH config:

```
docker context create docker-dev --docker "host=ssh://docker-dev"
```

Switch to the new context:

```
docker context use docker-dev
```

Now test that the connection works:

```
docker info | head -n 10
```

This should list the Docker Context you are using: `docker-dev`. If
you see this output, it is working!

## Create IAM policy and role for Route 53 ACME challenge

Later on you will be installing Traefik, which has the capability to
automatically provision TLS certificates for your domain name. To do
this, you need to give it permission to create DNS records in Route53.

Find the Hosted Zone ID for your domain:

 * Login to the Route53 dasbhoard.
 * Find the Hosted Zone that will be managed by this Docker instance
   and copy the `Hosted zone ID`.

Create the IAM policy:

 * Login to the IAM dashboard.
 * Click `Policies`.
 * Click `Create Policy`.
 * Choose the `JSON` policy editor.
 * Delete the example policy text, and paste the following in its place:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/Z11111112222222333333"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/Z11111112222222333333"
      ],
      "Condition": {
        "ForAllValues:StringEquals": {
          "route53:ChangeResourceRecordSetsNormalizedRecordNames": [
            "_acme-challenge.example.com"
          ],
          "route53:ChangeResourceRecordSetsRecordTypes": [
            "TXT"
          ]
        }
      }
    }
  ]
}
```
 
 * Replace both instances of the text `Z11111112222222333333` with
   your actual Hosted Zone id for your domain.
 * Replace the domain `example.com` with your actual domain name
   (leaving the `_acme-challenge.` prefix in place).
 * Click `Next`
 * Enter a descriptive policy name like `docker-dev-route53`.
 * Click `Create Policy`.

Create the IAM user:

 * Go to the IAM dashboard.
 * Go to the `Users` menu.
 * Click the `Create User` button.
 * Enter a descriptibe username, like `docker-dev-route53`.
 * Click `Next`.
 * Set permissions, choose `Attach policies directly`.
 * Search for the policy name you created before:
   `docker-dev-route53`, and select it.
 * Click `Next`.
 * Click `Create user`.
 * Find the new user in the list and click on it.
 * Click the `Security credentials` tab on the user page.
 * Click the `Create access key` button
 * Choose `Command Line interface (CLI)`.
 * Confirm the dialog, and click `Next`.
 * Set the description: `Traefik ACME challenge token for AWS Route53`
 * Click `Next`.
 * Copy the Access key and Secret key and save them in a temporary
   buffer somewhere.
 * Click `Done`.


## Setup your workstation with d.rymcg.tech tools

Follow the sections in the d.rymcg.tech README for [install
workstation
tools](https://github.com/EnigmaCurry/d.rymcg.tech#install-workstation-tools)
and [setup
workstation](https://github.com/EnigmaCurry/d.rymcg.tech#setup-workstation)
for setting up your Workstation. If you are on WSL2 or MacOS you
should install [Docker Desktop](https://docs.docker.com/desktop/).

Stop once you reach the `Setup SSH access to the server` as you have
already done so.

Next follow the section for [cloning the d.rymcg.tech git
repository](https://github.com/EnigmaCurry/d.rymcg.tech#clone-this-repository-to-your-workstation):

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ${HOME}/git/vendor/enigmacurry/d.rymcg.tech

cd ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
```

Install the [d.rymcg.tech CLI
tool](https://github.com/EnigmaCurry/d.rymcg.tech#using-the-drymcgtech-cli-script-optional),
by adding the following lines to your `~/.bashrc` file:

```
#### To enable Bash shell completion support for d.rymcg.tech,
#### add the following lines into your ~/.bashrc ::
export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"
```

Log out of your shell, and log back in to reload the config.

## Configure d.rymcg.tech with your Docker context

Run the [main
configuration](https://github.com/EnigmaCurry/d.rymcg.tech#main-configuration):

```
d.rymcg.tech make - config
```

(The `-` is usually where you specify an app, but `-` has a special
meaning to configure the root project, which you only need to do once
per docker context.)

Follow the directions from the config script, it will ask you some questions:

 * Enter `y` to create the config for the current docker context (docker-dev)
 * Enter the `ROOT_DOMAIN`: docker-dev.example.com
 * Say `y` to save your passwords in the passwords.json file.

## Configure Traefik

Run the config tool for Traefik:

```
d.rymcg.tech make traefik config
```

This will enter a menu system that shows all the config options of
Traefik. Do all of the following tasks:

 * Select `Create system user on Docker host`. It will ask you to
   Proceed, enter `y` and press Enter.
   
 * Select `Configure entrypoints (including dashboard)`:
   * Select `Configure available entrypoints`
   * Select `dashboard`
   * It will ask to enable the dashboard, say yes.
   * Enter a username for the dashboard, eg. `admin`
   * Leave the password blank, and it will create a secure random one for you.
   * It will ask you if you want to create additional users, say no.
   * It will ask you if you want to save the password in passowords.json, say yes.
   * Press ESC twice to go back to the main menu.
   
 * Select `Configure ACME (Lets's Encrypt)`
   * It will ask to enable ACME, say yes.
   * It will to use the production Let's Encrypt API, say yes.
   * Enter your email address.
   * It will ask you to use the ACME DNS challenge type, say yes.
   * It will ask you to enter the LEGO code for your DNS provider. For
     AWS Route53, enter the text `route53` (delete the default
     `digitalocean` answer).
   * It will next ask you to enter all of the required variable names
     for the LEGO code. Only enter the *names* of the variables, not
     their values. See the [LEGO docs for route53 as
     reference](https://go-acme.github.io/lego/dns/route53/). Enter
     these var names (delete the default answer which is
     `DO_AUTH_TOKEN`, which is for digitalocean only):
     
     * `TRAEFIK_ACME_DNS_VARNAME_1`: `AWS_ACCESS_KEY_ID`
     * `TRAEFIK_ACME_DNS_VARNAME_2`: `AWS_SECRET_ACCESS_KEY`
     * `TRAEFIK_ACME_DNS_VARNAME_3`: `AWS_REGION`
     * Enter blank for `TRAEFIK_ACME_DNS_VARNAME_4` to indicate you're
       done entering the var names.
       
   * Next it will ask you to provide the values for the var names you entered:
   
     * `AWS_ACCESS_KEY_ID`: Enter the access key id for the
       `docker-dev-route53` user.
     * `AWS_SECRET_ACCESS_KEY`: Enter the secret access key for the
       `docker-dev-route53` user.
     * `AWS_REGION`: Enter the AWS region that you use: eg.
       `us-east-1`.

   * Select `Configure TLS certificates and domains`
   
     * This will start the certificate manager menu.
     * To create a new certificate, type `c` and press Enter.
     * Enter the primary domain name for the docker server, which
       should be the fully qualified domain name:
       `docker-dev.example.com`
     * Enter the SANS domains, which are secondary names:
       * Enter `*.docker-dev.example.com`
       * Enter any more domains you want to add.
       * Enter a blank domain to end the SANS input.
     * It will ask you to verify and create the certificate, say yes.
     * Press `q` and Enter to quit the certificate manager menu.
   
   * Press ESC to exit the main menu.

## Install Traefik

```
d.rymcg.tech make traefik install
```

## Install whoami

```
d.rymcg.tech make whoami config
```

 * Choose the default domain name for the service: eg.
`whoami.docker-dev.example.com`
 * Choose no auth.

Install whoami:

```
d.rymcg.tech make whoami install
```

Wait a few minutes, so that the TLS certificate can be issued.

Open the whoami page in your browser:

```
d.rymcg.tech make whoami open
```

If this does not work, at least it should print the URL to copy and
paste. The example url would be
`http://whoami.docker-dev.example.com`.

If you see a warning about a self-signed certificate, wait a few more
minutes for the TLS certificate to be issued. Check the Traefik logs
for more information:

```
d.rymcg.tech make traefik logs
```

Once the TLS certificatre is issued, you should be able to see the
whoami output in your browser. Check the certificate icon, usually on
the left hand side of the browser URL bar. It should contain a report
about the TLS certificate being used. A valid TLS certificate will be
shown to be issued by Let's Encrypt, and it should show all the
domains that the certificate is valid for, including the wildcard
`*.docker-dev.example.com`, which is how the domain
`whoami.docker-dev.example.com` is able to work.

Whoami is just a simple service to test that the connection and TLS
certificate is working. You can leave the service up for more testing
later, or you can destroy it now:

```
d.rymcg.tech make whoami destroy
```

## Configure OAuth2 with GitHub identity provider

Let's configure OAuth2 authentication and Traefik Sentry authorization
using traefik-forward-auth. This will let users login through a third
party identity service. For this example, lets use GitHub as the
example provider. Authorized users will be able to login to your apps
using their GitHub identity.

### Create the GitHub oauth app

 * Go to [GitHub new applications
   page](https://github.com/settings/applications/new).
 * Register a new OAuth application:
   * Enter a name, just use the domain: `docker-dev.example.com`
   * Enter the URL: `http://docker-demo.example.com`
   * Enter the callback URL:
     `https://whoami.docker-demo.example.com/_oauth`
   * Click `Register application`
   * Click `Generate a new client secret`
   * Copy the `Client ID` and the `Client Secret` into a temporary
     buffer someplace (or just leave the page open for a bit, you'll
     need to copy from it later).

### Configure traefik-forward-auth

For now, the traefik-forward-auth Makefile does not support
configuring GitHub, so we need to create the .env file by hand.

Copy the default .env-dist file:

```
d.rymcg.tech make traefik-forward-auth config-dist
```

Open the file in your text editor:
`~/git/vendor/enigmacurry/d.rymcg.tech/traefik-forward-auth/.env_docker-dev_default`
(this example is the .env file for the specific Docker context name
`docker-dev`, yours may vary, check the output of the previous command
to be sure of the name.)

 * Set `TRAEFIK_FORWARD_AUTH_SECRET`: run `openssl rand -base64 45` to
   generate a long random secret value.
 * Search and replace all `example.com` with your Docker server's real
   sub-domain name: `docker-dev.example.com`.
 * Comment out, or remove, all the Gitea variables.
 * Uncomment all the GitHub variables.
 * Insert the value for
   `TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID` from the
   GitHub OAuth Client ID.
 * Insert the value for
   `TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET` from the
    GitHub OAuth Client Secret. 
 * Make sure you don't have any extra spaces in the values.
 * Save the file.

### Install traefik-forward-auth

```
d.rymcg.tech make traefik-forward-auth install
```

### Configure the Traefik Sentry groups

Create a new group to allow people to access the whoami service:

```
d.rymcg.tech make traefik config
```

 * Select `Configure middleware (including auth)`
   * Select `OAuth2 sentry authorization`
     * Select `Group Manager`
       * Select `Create a new group`
       * Enter the group name: `whoami`
       * It will ask if you want to add users to this group now. Say
         yes.
       * Enter the primary email address associated with your GitHub
         profile.
  * Press ESC to get back to main menu, it will ask you to restart
    Traefik, say yes, if you accidentally bypassed this question,
    simply run `d.rymcg.tech make traefik install`.
  * Press ESC again to quit the main menu.

## Redeploy whoami, now requiring OAuth2

Now lets redeploy the whoami app, but reconfigure it so that it
requires the user to login via GitHub, before the page is displayed:

Re-run the whoami config tool:

```
d.rymcg.tech make whoami config
```

 * Use the same hostname as before, it will be shown just as you entered it before.
 * Choose to use Oauth2 authentication
 * Choose the `whoami` authorization group.

Re-deploy whomai:

```
d.rymcg.tech make whoami install
```

Re-open the whoami page in your browser:

```
d.rymcg.tech make whoami open
```

This time you should now be redirected to GitHub to authorize the
application. Click the `Authorize <Username>` button.

Now you should be allowed to see the whoami page. The whoami output
reflects the HTTP request headers. Look in the output for the
`X-Forwarded-User`, this is the GitHub user that you authenticated
with.

Try logging in with a different GitHub user, and you should see the
message `Forbidden`, unless you add the user to the whoami group.

Currently, modifying the OAuth2 user groups requires restarting
Traefik each time. This can be improved by removing the sentry
authorization, and simply doing the authorization in the app itself,
based upon the `X-Forwarded-User` header. In this configuration, all
valid GitHub users would be passed to your application, and your
application would need to make the determination itself if the user
(email address) should be allowed access.

## Deploy a python web app in development mode

Create a new project directory anyplace you like:

```
mkdir -p ~/projects
cd ~/projects
```

You can create a new Python Flask project from a d.rymcg.tech
template:

```
d.rymcg.tech create py-test
```

Choose the `python-flask` template.

A new directory is created called `py-test`

```
cd py-test
```

Inside this directory you will see several new files inherited from
the template:

 * `README.md`
 * `Makefile`
 * `docker-compose.yaml`
 * `docker-compose.instance.yaml`
 * `.env-dist`
 * And one directory: `flask`

These are all the files you need for a new d.rymcg.tech based project.

Run the config tool:

```
make config
```

Enter the `PY_TEST_TRAEFIK_HOST` variable: the default will create a
valid domain based off of your current docker context, the default
should work out of the box.

Choose what kind of authentication you want, you can configure it to
use the same OAuth2 group (`whoami`) as before, it should work the
same way. HTTP Basic authenication uses a username and password that
you configure; it is somewhat easier to share links with clients this
way. If your Docker server is available on the internet, I would
recommend you configure at least some form of authentication,
otherwise you may get unwanted strangers looking at your development
sites.

There are few more env vars you should set in the
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file: 

 * You may restrict access by IP address by setting
`PY_TEST_IP_SOURCERANGE="x.x.x.x/32"` (replace `x.x.x.x` with your
workstation's public IP address.) This can be useful as an alternative
to setting up authentication.

 * Set `PY_TEST_DEVELOPMENT_MODE=true` to enable development mode in
   your python app.
   
Now deploy the app:

```
make install
```

Now open the app in your browser:

```
make open
```

(This might not work on WSL, I don't know. It works on Linux.)

Now run the development file synchronizer:

```
make dev-sync
```

Leave the `dev-sync` command running in your terminal, and open a new
terminal to continue running other things.

Now open the file in your text editor called `flask/app/__init__.py`.
This is the main application file. Edit the file to change its
behaviour. As soon as you save it, the `dev-sync` should automatically
synchronize it to the server. After a few seconds, the python app
should reload and your changes redeployed.

Check the application log for any errors:

```
make logs
````
