# certificate-ca

This is a simple script to manage an OpenSSL Certificate Authority inside of a
docker volume, and tool to generate and sign certificates and store these inside
other docker volumes.

Build the docker image (you only need to run this once, unless you modify the
source code later):

```
./cert-manager.sh build
```

Create the Certificate Authority :

```
./cert-manager.sh create_ca
```

Create and sign the certificate for a domain name:

```
./cert-manager.sh create ${SOME_DOMAIN_NAME}
```

The above steps will create a new Certificate Authority (idempotent) and store
it in a docker volume named `local-certificate-ca` (or override by setting
`CA_NAME` var). The certificate for the domain will be stored separately in
another docker volume named `local-certificate-ca_${SOME_DOMAIN_NAME}`.

The files it writes into the volume are:

 * `/private_key` - The private key for `${SOME_DOMAIN_NAME}`.
 * `/cert.pem` - The public certificate of `${SOME_DOMAIN_NAME}`.
 * `/ca.pem` - The public CA cert used to sign the certificate.
 * `/fullchain.pem` - Both cert.pem and ca.pem in one file.

You can list all of the volumes created by this script:

```
./cert-manager.sh list
```

If you want, you can delete volumes for a given domain name:

```
./cert-manager delete ${SOME_DOMAIN_NAME}
```

## Install the Certificate Authority

For your clients to use these certificates, they need to trust the certificate
authority that signed it, or they may trust the certificate directly. Most
applications rely upon a system wide trust store that lists the root certificate
authority. Some other applications also include the ability to "pin" a
certificate directly, without requiring any trusted certificate authority (eg.
Gajim allows this).

You may install the Certificate Authority into your root local trust store
(Note: these instructions may be specific to Arch Linux):

```
## WARNING: Do not do this on your personal systems! Use in development envs only!
# Print the Certificate Authority into a file named docker-ca.pem 
../certificate-ca/cert-manager.sh get_ca > docker-ca.pem

# Now install the CA certificate into the local root trust store:
sudo trust anchor docker-ca.pem

# You should find the new 'local_ca' certificate listed at the top:
trust list | head

# You can remove it later by specifying the full key as listed by 'trust list'
sudo trust anchor remove 'pkcs11:........'

# Always run update-ca-trust afterward:
sudo update-ca-trust
```

If you have installed the public key to your trust store, *any* certificate
signed by it will be trusted by your system. Therefore it is recommended only to
install the CA into the trust store of *containers*, and never on the same
system from which you run a web browser! If anyone ever discovers your CA
private key, they may sign any devious certificate you (or they) can imagine.

*This script is intended for devlopment purposes only*! (To use this in
production, you may consider utilizing the `cert-manager.sh` script on a private
docker server that is not connected to the internet, and only copying
certificates and public CA keys needed to your internet server, leaving the CA
private key only on the offline system.)
