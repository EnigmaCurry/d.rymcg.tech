# Faasd

[Faasd](https://github.com/openfaas/faasd) is a lightweight compute
platform for running "serverless" functions in short-lived containers
that are created on demand. Faasd does not natively support Docker (it
runs its own container runner and it is dependent on systemd),
however, it can be forced to run in Docker with
[sysbox](https://github.com/nestybox/sysbox#readme).

## Configure sysbox on the Docker host

Login to your Docker host as root, and install sysbox:

```
## Run this on the docker host:
(set -ex
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
     jq fuse rsync linux-headers-$(uname -r)
TMP_FILE=$(mktemp)
wget -O ${TMP_FILE} "https://downloads.nestybox.com/sysbox/releases/v0.6.4/sysbox-ce_0.6.4-0.linux_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/').deb"
dpkg -i ${TMP_FILE}
rm -f ${TMP_FILE})
```

## Config faasd

```
## Run this on your workstation:
d make faasd config
```

Enter the domain name to use for the service:

```stdout
# FAASD_TRAEFIK_HOST: Enter the faasd domain name (eg. faasd.example.com)
# : faasd.example.com
```

For testing purposes, you should choose to enable HTTP Basic
Authentication, with a username and password:

```
? Do you want to enable sentry authorization in front of this app (effectively making the entire site private)?
  No
> Yes, with HTTP Basic Authentication
  Yes, with Oauth2
  Yes, with Mutual TLS (mTLS)

Enter the username for HTTP Basic Authentication
: test

Enter the passphrase for test (leave blank to generate a random passphrase)
: a_secure_passphrase

> Would you like to create additional usernames (for the same access privilege)? No

> Would you like to export the usernames and cleartext passwords to the file passwords.js
n? No
```


## Install faasd

```
## Run this on your workstation:
d make faasd install
```

## Finish faasd install via the shell

Enter the faasd container shell:

```
## Run this on your workstation:
d make faasd shell
```

Inside the shell, run the faasd installation script:

```
# Run this in the faasd container shell:
~/git/vendor/openfaas/faasd/hack/install.sh 
```

## Setup container registry

Faasd deploys its containers by pulling from a Docker container
registry, so you must provision one yourself or use a third party
service.

 * Create a local Docker registry for testing purposes:
 
```
## Inside the faasd container shell:
podman run -d -p 5000:5000 --name registry registry:2
```

 * Create service files to start the registry on container startup:
 
```
## Inside the faasd container shell:
podman generate systemd --name registry --files --restart-policy always
mv container-registry.service /etc/systemd/system/
systemctl enable --now container-registry.service
```

## Retrieve Faasd admin password
   
Retrieve the password and save it someplace safe (the PASSWORD var
will be used temporarily):

```
## Inside the faasd container shell:
PASSWORD=$(sudo cat /var/lib/faasd/secrets/basic-auth-password)
echo ${PASSWORD}
```

### Log in with faas-cli

```
## Inside the faasd container shell:
export OPENFAAS_URL=http://localhost:8080
echo $PASSWORD | faas-cli login --password-stdin
```

## Create and test your own function

Create a new project directory (`hello`):

```
## Inside the faasd container shell:
faas-cli new --lang python3 \
  hello-world \
  --prefix localhost:5000
```

Build and install the image:

```
## Inside the faasd container shell:
faas-cli up -f hello-world.yml
```

Test the newly deployed function:

```
## Inside the faasd container shell:
echo "Hello faasd" | faas-cli invoke hello-world
# Hello faasd
```

Test via HTTP:

```
## Inside the faasd container shell:
curl -d "Hello curl" http://127.0.0.1:8080/function/hello-world
# Hello curl
```

Test asynchronous function with a callback webhook. Create a [postb.in
endpoint](https://www.postb.in) to use as a temporary webhook
receiver:

```
## Inside the faasd container shell:
POSTBIN=$(curl -X POST -d "" https://www.postb.in/api/bin | jq -r ".binId")
```

Test the function and pass the webhook:

```
## Inside the faasd container shell:
curl -d "Bonjour postb.in" \
  http://127.0.0.1:8080/async-function/hello-world \
  --header "X-Callback-Url: https://www.postb.in/${POSTBIN}" 
```

Retrieve (and remove) the response from the receiver:

```
## Inside the faasd container shell:
curl https://www.postb.in/api/bin/${POSTBIN}/req/shift | jq -r ".body | keys[]"
```

This should respond with the same text you sent: `Bonjour postb.in`.

## Test public route to function

```
curl -L -d "Hello public" https://test:a_secure_passphrase@faasd.example.com/function/hello-world
```

This should route your domain name (`faasd.example.com`) TLS port
`443` through Traefik, verifying your username and password, and then
forward to the faasd backend port `8080`.
