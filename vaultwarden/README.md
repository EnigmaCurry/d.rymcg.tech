# Vaultwarden

[Vaultwarden](https://github.com/dani-garcia/vaultwarden) is an
unofficial [Bitwarden](https://bitwarden.com/) compatible server
rewritten in Rust, formerly known as bitwarden_rs.

```
make config
```

Check the config in the `.env_${DOCKER_CONTEXT}_${INSTANCE}` file.
Check that the pinned `VAULTWARDEN_VERSION` is actually the latest
version.

```
make install
```

```
# Check the status, wait for it to say `healthy`, then press Ctrl-C when done:
watch make status
```

Wait for the service to be healthy, then Traefik will allow access: 

```
make open
```

This will open the instance URL in your web browser. Click the `Create
account` link on the first page and create an account.

You may now disable registration and restart:

```
# Disable public registration
make disable-registration
```

(Note: when disabled the `Create Account` link will still be visible
on the login page, but the form will not be functional.)

If you need to create additional accounts later, you can re-enable
registration:

```
# Allow public registrations, but don't forget to disable this again later.
gmake enable-registration
```

## Security

Obviously, there are many security concerns when hosting a password
manager, especially on any network. On the other hand, it is nice to
be able to centralize a shared repository of passwords, and give
invitations to allow access from authenticated friends. There are a
few mitigations you can apply to make this a bit more secure:

 * Although you *can* run this on the internet, you should first
   consider running this on a private docker server, that is behind a
   firewall, or you may setup the [Traefik wireguard
   VPN](../traefik/README.md#wireguard-vpn), or you might use the
   [_docker_vm](../_docker_vm) to run it locally. In any case, you
   will want to configure Traefik for the ACME DNS Challenge, so that
   you can still use Lets Encrypt TLS certificates, from behind these
   firewalls.
 * Make sure to disable public registration, set
   `VAULTWARDEN_SIGNUPS_ALLOWED=false` in the
   `.env_{DOCKER_CONTEXT}_{INSTANCE}` file (or run `make
   disable-registration`).
 * By default this container accepts connections from all IP
   addresses, however you can limit this by editing the
   `VAULTWARDEN_IP_SOURCERANGE` variable in the
   `.env_{DOCKER_CONTEXT}_{INSTANCE}` file (and run `make install` to
   apply it). The variable accepts multiple CIDR IP addresses as a
   whitelist. For example, if you wanted to only allow two different
   IP adresses, you could set it like this:
   `VAULTWARDEN_IP_SOURCERANGE=192.168.45.13/32,10.10.10.1/32`. For
   more information see the [Traefik IPWhitelist
   docs](https://doc.traefik.io/traefik/middlewares/http/ipwhitelist/).
 * Use a hardware key with webauthn support, like
   [solokey](https://solokeys.com/).
 * Disable invitations, set `VAULTWARDEN_INVITATIONS_ALLOWED=false`.
 * Increase the KDF iterations in the Security settings.
 * Use one of the [Bitwarden apps](https://bitwarden.com/download/)
   instead of your web browser.
