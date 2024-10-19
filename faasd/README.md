# Faasd

[Faasd](https://github.com/openfaas/faasd) is a lightweight compute
platform for running serverless functions in short-lived containers
created on demand. Faasd does not natively support Docker, it runs its
own container runner, and it is also dependent on systemd. However, it
can be forced to run in Docker with
[sysbox-systemd](../sysbox-systemd).

## Configure sysbox container

 * Setup your Docker host with
   [d.rymcg.tech](https://github.com/enigmacurry/d.rymcg.tech#readme).
 * Install
   [sysbox-systemd](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/sysbox-systemd#readme).

> ℹ️ These instructions assume you have a d.rymcg.tech context alias
> named `d`, but your alias may be different.

Configure the container:

```
d make sysbox-systemd config
```

Give the container system root privileges:

```
d make sysbox-systemd reconfigure var=SYSBOX_PRIVILEGED=true
```

Install it:

```
d make sysbox-systemd install
```

Enter the shell for the container:

```
d make sysbox-systemd shell
```

Show that systemd is running:

```
## Inside the sysbox container shell:
systemctl status
```

Install podman and configure it to masquerade as Docker:
 
```
## Inside the sysbox container shell:
sudo apt update
sudo apt install -y git jq podman

sudo ln -s /usr/bin/podman /usr/local/bin/docker

cat <<EOF | sudo tee /etc/containers/containers.conf
[engine]
cgroup_manager = "cgroupfs"
EOF
```

> ℹ️ Configuring the cgroup_manager is done to avoid this error: `Error:
> cannot open sd-bus: No such file or directory: OCI not found`

 * Create a local Docker registry
 
```
sudo podman run -d -p 5000:5000 --name registry registry:2
```

 * Configure podman to use the local registry:
 
```
cat <<'EOF' | sudo tee /etc/containers/registries.conf.d/localhost.conf
unqualified-search-registries=["localhost:5000","docker.io"]

[[registry]]
location="localhost:5000"
insecure=true
EOF
```

 * [[https://blog.alexellis.io/faasd-for-lightweight-serverless/][Install
faasd according to the Raspberry Pi docs]], abbreviated here:
   
```
## In the faasd VM:
git clone https://github.com/openfaas/faasd ~/git/vendor/openfaas/faasd
cd ~/git/vendor/openfaas/faasd
sudo ./hack/install.sh
```
   
Faasd should now be running via systemd:

```
## In the faasd VM:
sudo systemctl status faasd
sudo systemctl status faasd-provider

sudo journalctl -t default:gateway --lines 40
sudo journalctl -t default:nats --lines 40
sudo journalctl -t default:queue-worker --lines 40
sudo journalctl -t default:prometheus --lines 40
```

Retrieve the password and save it someplace safe (the PASSWORD var
will be used temporarily):

```
PASSWORD=$(sudo cat /var/lib/faasd/secrets/basic-auth-password)
echo ${PASSWORD}
```

### Log in with faas-cli

> ℹ️ You can login directly from the VM, or remotely by changing
> `localhost` to the IP address of the VM:

```
export OPENFAAS_URL=http://localhost:8080
echo $PASSWORD | faas-cli login --password-stdin

# Calling the OpenFaaS server to validate the credentials...
# credentials saved for admin http://localhost:8080
```

### Install a demo function

If your faasd host is not `x86_64`, you must configure the host system
architecture when installing any image (the following commands will
default to `x86_64` unless you set a different PLATFORM var):

```
## Pick your (remote) host faasd platform:
#PLATFORM=arm64
#PLATFORM=armhf
PLATFORM=x86_64
```

There are some demo functions you can install:

```
faas-cli store list --platform ${PLATFORM:-x86_64}
```

Install the `figlet` function:

```
faas-cli store deploy --platform ${PLATFORM:-x86_64} figlet
faas-cli ready figlet
```

This prints the deployment URL:
`http://localhost:8080/function/figlet`.

You can run the function directly from the command line:

```
echo "Hello faasd" | faas-cli invoke figlet
```

### Install an async function

```
faas-cli store deploy --platform ${PLATFORM:-x86_64} nodeinfo
faas-cli ready nodeinfo
```

Async functions run a function in the background and when it's done
later it posts the results to a webhook. 

Create a [postb.in endpoint](https://www.postb.in) to use as a
temporary webhook receiver:

```
POSTBIN=$(curl -X POST -d "" https://www.postb.in/api/bin | jq -r ".binId")
```

Test the function and pass the webhook:

```
curl -d "verbose" \
  http://127.0.0.1:8080/async-function/nodeinfo \
  --header "X-Callback-Url: https://www.postb.in/${POSTBIN}" 
```

Retrieve (and remove) the response from the receiver:

```
curl https://www.postb.in/api/bin/${POSTBIN}/req/shift | jq
```

You can invoke the function again and you should have another response
to retrieve.

### List installed functions and stats

```
faas-cli list

# Function                      	Invocations    	Replicas
# figlet                        	4              	1
# nodeinfo                      	4              	1
```

### Create a new function

Create a new project directory (`hello`):

```
## Run this in the VM where the registry is running (localhost:5000):
faas-cli new --lang python3 \
  hello-world \
  --prefix localhost:5000
```

Build and install the image:

```
faas-cli up -f hello-world.yml
```

Test the newly deployed function:

```
echo "Hello faasd" | faas-cli invoke hello-world

# Hello faasd
```

Create a [postb.in endpoint](https://www.postb.in) to use as a
temporary webhook receiver:

```
POSTBIN=$(curl -X POST -d "" https://www.postb.in/api/bin | jq -r ".binId")
```

Test the function and pass the webhook:

```
curl -d "Hello faasd" \
  http://127.0.0.1:8080/async-function/hello-world \
  --header "X-Callback-Url: https://www.postb.in/${POSTBIN}" 
```

Retrieve (and remove) the response from the receiver:

```
curl https://www.postb.in/api/bin/${POSTBIN}/req/shift | jq
```

