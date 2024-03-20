# doh-server

[doh-server](https://github.com/DNSCrypt/doh-server) is a
DNS-over-HTTPs server. You can use it as a secure proxy for your
client DNS requests, and it is espcially easy to setup for various
web-browsers like Firefox and/or chromium.

## Warning

DNS over HTTPs (DOH) has some pros *and* cons compared to the
competition. On the one hand it is very easy to implement client-side.
In fact, if you only care about securing your web browser, you can
just stick it into your browser settings and go. However, the security
of DOH relies upon the security of TLS, and the security of TLS relies
upon the security of the root TLS certificate authorities. Herin lies
the problem: ANY root certificate authority can sign ANY TLS
certificate. If you don't trust ALL of them, you can't trust ANY of
them. If you don't control the root operating system (eg. corporate
issued laptop) ALL bets are off. Modern browsers got rid of [HTTP
Public Key
Pinning](https://en.wikipedia.org/wiki/HTTP_Public_Key_Pinning) (HPKP)
in favor of [Certificate
Transparency](https://en.wikipedia.org/wiki/Certificate_Transparency),
however this is of little comfort if you realize that the CT logs are
voluntary, and could be forged/ommitted if ANY participating
certificate authority chooses to do so, and not even all authorities
participate. So, caveat emptor.

Although no modern browser supports HPKP anymore, you can still
[install an
extension](https://addons.mozilla.org/en-US/firefox/addon/certificate-pinner/)
that will at least alert you in the case that any certificate changes
(however, this can lead to many false-positives that HPKP wouldn't
have had, as certificates can change for legitimate reasons, and
there's no way to tell unless you personally know the admin of the
site.)

Protocols like
[DNSCrypt](https://github.com/DNSCrypt/dnscrypt-proxy#readme) are not
as easy to deploy, especially client side, because you need to
configure the public key. However, because DNScrypt offers mutual
authentication, it is far safer than relying upon the hundreds of
certifcate authorities, ANY one of which can break the ENTIRE system.
So, caveat emptor.

DNS over HTTPs is typically used as an *application layer* DNS
resolver, not for your entire operating system. For example, you can
setup Firefox to use DOH, and it will completely bypass the default
operating system DNS resolver. For whole-system encrypted DNS, choose
[dnscrypt-proxy](https://wiki.archlinux.org/title/Dnscrypt) instead.

If you use a mobile phone or workstation, one that connects to various
wifi access points, DNS over HTTPs is still probably better than doing
raw unencrypted DNS over port 53. The DOH server will not make you
anonymous, but it will at least hide your client IP address making DNS
requests.

## Config

```
make config
```

Answer the questions to provide:

 * `DOH_TRAEFIK_HOST` the domain name of your new DNS over HTTPs server.
 * `DOH_PUBLIC_IP_ADDRESS` the doh-server needs to know your Docker host's public IP address.
 * `DOH_UPSTREAM_DNS` the doh-server needs an upstream DNS provider
   (eg. [9.9.9.9](https://www.quad9.net/))
 * `DOH_UPSTREAM_DNS_PORT` the doh-server needs to know the upstream
   DNS port number (usually 53).
   
## Install

```
make install
```

## Test the DNS

Install the `dig` tool on your workstation. Usually the package is
called `dnsutils`.

```
dig +https @dns.example.com news.ycombinator.com
```

Replace the `dns.example.com` with the domain name of your doh-server.
Check that you receive a valid response containing the IP address of
news.ycombinator.com.

## Configure Firefox for DNS-over-HTTPs

In the Firefox settings, under `Privacy and Security`, all the way at
the bottom, set `Enable secure DNS` and choose `Max Protection`. In
the drop down list, choose `Custom`, and set the URL to
`https://dns.example.com/dns-query` (replace `dns.example.com` with
your actual DOH server address.)
