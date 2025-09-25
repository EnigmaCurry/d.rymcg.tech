# Tour of d.rymcg.tech

This guide will show you how to configure d.rymcg.tech on a fresh
Docker server with a suggested set of initial services. 

For a comprehensive list of all the serices provided by d.rymcg.tech,
please consult [README.md](README.md#services)

## Requirements

This guide assumes that you have already performed the following
steps:

  * Create your workstation (choose one):
 
    * [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Setup your workstation on Linux.
    * [WORKSTATION_WSL.md](WORKSTATION_WSL.md) - Setup your workstation on Windows (WSL).

  * Create your Docker server:
  
    * [DOCKER.md](DOCKER.md) - Create your Docker server on bare
      metal, VM, or cloud server.

All of the commands written in this guide are to be run on your
workstation:

  * Switch your workstation's Docker context to the server you wish to
    control:
    
```
d context
```

## Context config

```
d config
```

```
> This will make a configuration for the current docker context (insulon). Proceed? Yes
ROOT_DOMAIN: Enter the root domain for this context (eg. d.example.com)
: insulon.rymcg.tech
Configured .env_insulon
ENV_FILE=.env_insulon_default

> Is this server behind another trusted proxy using the proxy protocol? No
Set DEFAULT_CLI_ROUTE_LAYER_7_PROXY_PROTOCOL=false
Set DEFAULT_CLI_ROUTE_LAYER_4_PROXY_PROTOCOL=false

> Do you want to save cleartext passwords in passwords.json by default? No
Set DEFAULT_SAVE_CLEARTEXT_PASSWORDS_JSON=false
```

## Traefik

```bash
d make traefik config
```

### Config

#### Traefik user

Create the traefik user.

#### TLS certificates and authorities

#### Configure TLS certificates (`make certs`)

##### Create a new certificate

Create a new wildcard certificate for your domain:

```text
Enter the main domain (CN) for this certificate (eg. `d.rymcg.tech` or `*.d.rymcg.tech`)
: insulon.rymcg.tech
Now enter additional domains (SANS), one per line:
Enter a secondary domain (enter blank to skip)
: *.insulon.rymcg.tech
Enter a secondary domain (enter blank to skip)
:

Main domain:
 insulon.rymcg.tech
Secondary (SANS) domains:
 *.insulon.rymcg.tech
```

Choose `Done`.

#### Configure ACME (Let's Encrypt or Step-CA)

##### Acme.sh + acme-dns

###### Let's Encrypt (production)

```text
> Which ACME provider do you want to use? Acme.sh + ACME-DNS (new; recommended!)
Set TRAEFIK_ACME_ENABLED=false
Set TRAEFIK_STEP_CA_ENABLED=false
Set TRAEFIK_ACME_SH_ENABLED=true
Set TRAEFIK_ACME_CHALLENGE=dns

> Which ACME server should acme.sh use? Let's Encrypt (production)
Set TRAEFIK_ACME_SH_ACME_CA=acme-v02.api.letsencrypt.org
Set TRAEFIK_ACME_SH_ACME_DIRECTORY=/directory
Set TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE=true

TRAEFIK_ACME_SH_ACME_DNS_BASE_URL: ACME-DNS base URL (e.g. https://auth.acme-dns.example.net) (eg. https://auth.acme-dns.io)
: https://auth.acme-dns.io

TRAEFIK_ACME_SH_DNS_RESOLVER: Trusted DNS resolver IP used inside acme-sh container (eg. 1.1.1.1)
: 1.1.1.1

TRAEFIK_ACME_SH_CERT_PERIOD_HOURS: Validity target in hours (e.g. 48 for Step-CA, 2160 for LE) (eg. 1440)
: 1440
Set TRAEFIK_ACME_SH_ACMEDNS_ACCOUNT_JSON=/acme.sh/acmedns-account.json

TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM: acme-dns allow_from (JSON array or comma list; blank to skip)
:
```

#### Create DNS records (CNAME and A)

Look for the CNAME records output to the screen, e.g.:

```text
### EXAMPLE:
Create these CNAME records (on your root domain's DNS server) BEFORE traefik install:

    _acme-challenge.insulon.rymcg.tech.   CNAME   615b56da-6105-4b80-baee-7612decd3b06.auth.acme-dns.io.
```

You must create the `CNAME` record on your root domain's DNS server.

You must also create a wildcard `A` record for your clients to access the services, e.g.:

```text
### EXAMPLE:
    *.insulon.rymcg.tech.   A   123.123.123.123
```

### Install Traefik

Go back to the main menu and choose `Install (make install)`.

#### Check acme-sh logs for issuance of the certificate

```bash
d make traefik logs service=acme-sh
```

Look in the log for the certificate to be successfully issued:

```text
acme-sh-1  | 2025-09-12T18:16:01.965738376Z
acme-sh-1  | 2025-09-12T18:16:01.970307171Z [entrypoint:acme-sh] Public ACME CA detected (acme-v02.api.letsencrypt.org); skipping TOFU and using system trust.
acme-sh-1  | 2025-09-12T18:16:01.970328612Z [entrypoint:acme-sh] Using system trust store only: /etc/ssl/certs/ca-certificates.crt
acme-sh-1  | 2025-09-12T18:16:02.291928260Z [entrypoint:acme-sh] dns_acmedns: hydrated missing envs from /acme.sh/acmedns-account.json
acme-sh-1  | 2025-09-12T18:16:02.292281439Z [entrypoint:acme-sh] ACME server: https://acme-v02.api.letsencrypt.org/directory
acme-sh-1  | 2025-09-12T18:16:02.292487082Z [entrypoint:acme-sh] Target validity: +1440h
acme-sh-1  | 2025-09-12T18:16:02.292689059Z [entrypoint:acme-sh] Let's Encrypt detected; skipping --valid-to (LE does not support NotBefore/NotAfter).
acme-sh-1  | 2025-09-12T18:16:02.991015073Z [entrypoint:acme-sh] Requesting certificate:
acme-sh-1  | 2025-09-12T18:16:02.991023715Z [entrypoint:acme-sh]   CN:   insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:16:02.991026764Z [entrypoint:acme-sh]   SANs: *.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:16:04.468239771Z [Fri Sep 12 18:16:04 UTC 2025] Using CA: https://acme-v02.api.letsencrypt.org/directory
acme-sh-1  | 2025-09-12T18:16:04.585778816Z [Fri Sep 12 18:16:04 UTC 2025] Account key creation OK.
acme-sh-1  | 2025-09-12T18:16:04.747781785Z [Fri Sep 12 18:16:04 UTC 2025] Registering account: https://acme-v02.api.letsencrypt.org/directory
acme-sh-1  | 2025-09-12T18:16:05.311626804Z [Fri Sep 12 18:16:05 UTC 2025] Registered
acme-sh-1  | 2025-09-12T18:16:05.379359119Z [Fri Sep 12 18:16:05 UTC 2025] ACCOUNT_THUMBPRINT='I4UN5usfnES9PFCVRQ_-BAjb-Lo_QVyVOI7zlEbxcLU'
acme-sh-1  | 2025-09-12T18:16:05.386038497Z [Fri Sep 12 18:16:05 UTC 2025] Creating domain key
acme-sh-1  | 2025-09-12T18:16:05.433936403Z [Fri Sep 12 18:16:05 UTC 2025] The domain key is here: /acme.sh/insulon.rymcg.tech_ecc/insulon.rymcg.tech.key
acme-sh-1  | 2025-09-12T18:16:05.502638058Z [Fri Sep 12 18:16:05 UTC 2025] Multi domain='DNS:insulon.rymcg.tech,DNS:*.insulon.rymcg.tech'
acme-sh-1  | 2025-09-12T18:16:07.297929241Z [Fri Sep 12 18:16:07 UTC 2025] Getting webroot for domain='insulon.rymcg.tech'
acme-sh-1  | 2025-09-12T18:16:07.468740195Z [Fri Sep 12 18:16:07 UTC 2025] Getting webroot for domain='*.insulon.rymcg.tech'
acme-sh-1  | 2025-09-12T18:16:07.717317190Z [Fri Sep 12 18:16:07 UTC 2025] Adding TXT value: sQIpN5QKXCeCh5X5eVOfBTr9NvC5F8DILoaV9KxMrK0 for domain: _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:16:07.727250464Z [Fri Sep 12 18:16:07 UTC 2025] Using acme-dns
acme-sh-1  | 2025-09-12T18:16:08.782448051Z [Fri Sep 12 18:16:08 UTC 2025] The TXT record has been successfully added.
acme-sh-1  | 2025-09-12T18:16:08.834508315Z [Fri Sep 12 18:16:08 UTC 2025] Adding TXT value: AYWMHUQL62NQGtifjwfHAN48Iy-TeOTq12LyL1I0OKU for domain: _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:16:08.837331043Z [Fri Sep 12 18:16:08 UTC 2025] Using acme-dns
acme-sh-1  | 2025-09-12T18:16:09.926056295Z [Fri Sep 12 18:16:09 UTC 2025] The TXT record has been successfully added.
acme-sh-1  | 2025-09-12T18:16:09.929443427Z [Fri Sep 12 18:16:09 UTC 2025] Let's check each DNS record now. Sleeping for 20 seconds first.
acme-sh-1  | 2025-09-12T18:16:29.942593404Z [Fri Sep 12 18:16:29 UTC 2025] You can use '--dnssleep' to disable public dns checks.
acme-sh-1  | 2025-09-12T18:16:29.945972468Z [Fri Sep 12 18:16:29 UTC 2025] See: https://github.com/acmesh-official/acme.sh/wiki/dnscheck
acme-sh-1  | 2025-09-12T18:16:30.006309137Z [Fri Sep 12 18:16:30 UTC 2025] Checking insulon.rymcg.tech for _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:16:34.399558627Z [Fri Sep 12 18:16:34 UTC 2025] Not valid yet, let's wait for 10 seconds then check the next one.
acme-sh-1  | 2025-09-12T18:16:44.804378735Z [Fri Sep 12 18:16:44 UTC 2025] Checking insulon.rymcg.tech for _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:16:48.908999963Z [Fri Sep 12 18:16:48 UTC 2025] Not valid yet, let's wait for 10 seconds then check the next one.
acme-sh-1  | 2025-09-12T18:16:59.178797519Z [Fri Sep 12 18:16:59 UTC 2025] Let's wait for 10 seconds and check again.
acme-sh-1  | 2025-09-12T18:17:09.187850314Z [Fri Sep 12 18:17:09 UTC 2025] You can use '--dnssleep' to disable public dns checks.
acme-sh-1  | 2025-09-12T18:17:09.191592674Z [Fri Sep 12 18:17:09 UTC 2025] See: https://github.com/acmesh-official/acme.sh/wiki/dnscheck
acme-sh-1  | 2025-09-12T18:17:09.243596011Z [Fri Sep 12 18:17:09 UTC 2025] Checking insulon.rymcg.tech for _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:13.332990454Z [Fri Sep 12 18:17:13 UTC 2025] Not valid yet, let's wait for 10 seconds then check the next one.
acme-sh-1  | 2025-09-12T18:17:23.759202184Z [Fri Sep 12 18:17:23 UTC 2025] Checking insulon.rymcg.tech for _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:24.155289461Z [Fri Sep 12 18:17:24 UTC 2025] Success for domain insulon.rymcg.tech '_acme-challenge.insulon.rymcg.tech'.
acme-sh-1  | 2025-09-12T18:17:24.158793755Z [Fri Sep 12 18:17:24 UTC 2025] Let's wait for 10 seconds and check again.
acme-sh-1  | 2025-09-12T18:17:34.167424092Z [Fri Sep 12 18:17:34 UTC 2025] You can use '--dnssleep' to disable public dns checks.
acme-sh-1  | 2025-09-12T18:17:34.170488792Z [Fri Sep 12 18:17:34 UTC 2025] See: https://github.com/acmesh-official/acme.sh/wiki/dnscheck
acme-sh-1  | 2025-09-12T18:17:34.222323903Z [Fri Sep 12 18:17:34 UTC 2025] Checking insulon.rymcg.tech for _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:34.621515846Z [Fri Sep 12 18:17:34 UTC 2025] Success for domain insulon.rymcg.tech '_acme-challenge.insulon.rymcg.tech'.
acme-sh-1  | 2025-09-12T18:17:34.666610500Z [Fri Sep 12 18:17:34 UTC 2025] Checking insulon.rymcg.tech for _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:34.670995274Z [Fri Sep 12 18:17:34 UTC 2025] Already succeeded, continuing.
acme-sh-1  | 2025-09-12T18:17:34.673988560Z [Fri Sep 12 18:17:34 UTC 2025] All checks succeeded
acme-sh-1  | 2025-09-12T18:17:34.698678061Z [Fri Sep 12 18:17:34 UTC 2025] Verifying: insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:35.054156018Z [Fri Sep 12 18:17:35 UTC 2025] Pending. The CA is processing your order, please wait. (1/30)
acme-sh-1  | 2025-09-12T18:17:37.433224258Z [Fri Sep 12 18:17:37 UTC 2025] Success
acme-sh-1  | 2025-09-12T18:17:37.460369898Z [Fri Sep 12 18:17:37 UTC 2025] Verifying: *.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:37.850095959Z [Fri Sep 12 18:17:37 UTC 2025] Pending. The CA is processing your order, please wait. (1/30)
acme-sh-1  | 2025-09-12T18:17:40.195027089Z [Fri Sep 12 18:17:40 UTC 2025] Success
acme-sh-1  | 2025-09-12T18:17:40.201499188Z [Fri Sep 12 18:17:40 UTC 2025] Removing DNS records.
acme-sh-1  | 2025-09-12T18:17:40.227878562Z [Fri Sep 12 18:17:40 UTC 2025] Removing txt: sQIpN5QKXCeCh5X5eVOfBTr9NvC5F8DILoaV9KxMrK0 for domain: _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:40.230951400Z [Fri Sep 12 18:17:40 UTC 2025] Using acme-dns
acme-sh-1  | 2025-09-12T18:17:40.234062258Z [Fri Sep 12 18:17:40 UTC 2025] Successfully removed
acme-sh-1  | 2025-09-12T18:17:40.263533171Z [Fri Sep 12 18:17:40 UTC 2025] Removing txt: AYWMHUQL62NQGtifjwfHAN48Iy-TeOTq12LyL1I0OKU for domain: _acme-challenge.insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:40.266822692Z [Fri Sep 12 18:17:40 UTC 2025] Using acme-dns
acme-sh-1  | 2025-09-12T18:17:40.269650406Z [Fri Sep 12 18:17:40 UTC 2025] Successfully removed
acme-sh-1  | 2025-09-12T18:17:40.281446614Z [Fri Sep 12 18:17:40 UTC 2025] Verification finished, beginning signing.
acme-sh-1  | 2025-09-12T18:17:40.306160284Z [Fri Sep 12 18:17:40 UTC 2025] Let's finalize the order.
acme-sh-1  | 2025-09-12T18:17:40.309354833Z [Fri Sep 12 18:17:40 UTC 2025] Le_OrderFinalize='https://acme-v02.api.letsencrypt.org/acme/finalize/2656989411/427395475441'
acme-sh-1  | 2025-09-12T18:17:40.905359297Z [Fri Sep 12 18:17:40 UTC 2025] Downloading cert.
acme-sh-1  | 2025-09-12T18:17:40.908282353Z [Fri Sep 12 18:17:40 UTC 2025] Le_LinkCert='https://acme-v02.api.letsencrypt.org/acme/cert/06b4671559abf824dc5bb823f6816adcc524'
acme-sh-1  | 2025-09-12T18:17:41.315548009Z [Fri Sep 12 18:17:41 UTC 2025] Cert success.
acme-sh-1  | 2025-09-12T18:17:41.318576644Z -----BEGIN CERTIFICATE-----
acme-sh-1  | 2025-09-12T18:17:41.318624706Z MIIDpDCCAyugAwIBAgISBrRnFVmr+CTcW7gj9oFq3MUkMAoGCCqGSM49BAMDMDIx
acme-sh-1  | 2025-09-12T18:17:41.318632087Z CzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQDEwJF
acme-sh-1  | 2025-09-12T18:17:41.318637052Z ODAeFw0yNTA5MTIxNzE5MTBaFw0yNTEyMTExNzE5MDlaMB0xGzAZBgNVBAMTEmlu
acme-sh-1  | 2025-09-12T18:17:41.318642014Z c3Vsb24ucnltY2cudGVjaDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABPvdpNQ0
acme-sh-1  | 2025-09-12T18:17:41.318646363Z 6k65sdZTAhZWxBN/9Jc4MSjAuvljH7/8aO9jAIG+UoahQ/QTRovFqwm9wh7gSQSV
acme-sh-1  | 2025-09-12T18:17:41.318651765Z U7eLTHBbtypZgRCjggI0MIICMDAOBgNVHQ8BAf8EBAMCB4AwHQYDVR0lBBYwFAYI
acme-sh-1  | 2025-09-12T18:17:41.318656878Z KwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFA9RNDM1
acme-sh-1  | 2025-09-12T18:17:41.318662027Z 24GI3rlOZfUg234r0+gQMB8GA1UdIwQYMBaAFI8NE6L2Ln7RUGwzGDhdWY4jcpHK
acme-sh-1  | 2025-09-12T18:17:41.318667243Z MDIGCCsGAQUFBwEBBCYwJDAiBggrBgEFBQcwAoYWaHR0cDovL2U4LmkubGVuY3Iu
acme-sh-1  | 2025-09-12T18:17:41.318672434Z b3JnLzAzBgNVHREELDAqghQqLmluc3Vsb24ucnltY2cudGVjaIISaW5zdWxvbi5y
acme-sh-1  | 2025-09-12T18:17:41.318806972Z eW1jZy50ZWNoMBMGA1UdIAQMMAowCAYGZ4EMAQIBMC0GA1UdHwQmMCQwIqAgoB6G
acme-sh-1  | 2025-09-12T18:17:41.318815566Z HGh0dHA6Ly9lOC5jLmxlbmNyLm9yZy8zNy5jcmwwggECBgorBgEEAdZ5AgQCBIHz
acme-sh-1  | 2025-09-12T18:17:41.318821238Z BIHwAO4AdQAN4fIwK9MNwUBiEgnqVS78R3R8sdfpMO8OQh60fk6qNAAAAZk/Jbf+
acme-sh-1  | 2025-09-12T18:17:41.318826084Z AAAEAwBGMEQCICtsJRTQ3k2mh50NY5WGxzY6b6vCp4xVGh4brlBU5M/UAiBXGl0c
acme-sh-1  | 2025-09-12T18:17:41.318830856Z +PxX8ujNLryZtoi9jIVYbz0hwz+EIapeOr0sfgB1ABoE/0nQVB1Ar/agw7/x2MRn
acme-sh-1  | 2025-09-12T18:17:41.318836150Z L07s7iNAaJhrF0Au3Il9AAABmT8luD4AAAQDAEYwRAIgDxzo1gOy936gDA/Gworv
acme-sh-1  | 2025-09-12T18:17:41.318855970Z qX2pB/QVQUIAIAmqE/YkTBwCIDskHsOxCSNUf1E5drVgns+FMtwrkeMjsB+lWgyy
acme-sh-1  | 2025-09-12T18:17:41.318861388Z 00O3MAoGCCqGSM49BAMDA2cAMGQCMAC3xDSYS0TlqWiuHl/AeStLOe4vUOUG/i5I
acme-sh-1  | 2025-09-12T18:17:41.318866529Z hWspA621HP9cIhQGcemu77GL0gH4SQIwBrQBATaL14gwKNqGsiCNvoJwq156mYEH
acme-sh-1  | 2025-09-12T18:17:41.318884957Z VwlC9XlAcH1BNRdL0H7Vlfb1z9KxQ2dQ
acme-sh-1  | 2025-09-12T18:17:41.318890370Z -----END CERTIFICATE-----
acme-sh-1  | 2025-09-12T18:17:41.325677668Z [Fri Sep 12 18:17:41 UTC 2025] Your cert is in: /acme.sh/insulon.rymcg.tech_ecc/insulon.rymcg.tech.cer
acme-sh-1  | 2025-09-12T18:17:41.329685309Z [Fri Sep 12 18:17:41 UTC 2025] Your cert key is in: /acme.sh/insulon.rymcg.tech_ecc/insulon.rymcg.tech.key
acme-sh-1  | 2025-09-12T18:17:41.339824563Z [Fri Sep 12 18:17:41 UTC 2025] The intermediate CA cert is in: /acme.sh/insulon.rymcg.tech_ecc/ca.cer
acme-sh-1  | 2025-09-12T18:17:41.343650288Z [Fri Sep 12 18:17:41 UTC 2025] And the full-chain cert is in: /acme.sh/insulon.rymcg.tech_ecc/fullchain.cer
acme-sh-1  | 2025-09-12T18:17:41.536989549Z [Fri Sep 12 18:17:41 UTC 2025] The domain 'insulon.rymcg.tech' seems to already have an ECC cert, let's use it.
acme-sh-1  | 2025-09-12T18:17:41.621268040Z [Fri Sep 12 18:17:41 UTC 2025] Installing cert to: /certs/insulon.rymcg.tech/cert.cer
acme-sh-1  | 2025-09-12T18:17:41.628549032Z [Fri Sep 12 18:17:41 UTC 2025] Installing CA to: /certs/insulon.rymcg.tech/ca.cer
acme-sh-1  | 2025-09-12T18:17:41.635783256Z [Fri Sep 12 18:17:41 UTC 2025] Installing key to: /certs/insulon.rymcg.tech/insulon.rymcg.tech.key
acme-sh-1  | 2025-09-12T18:17:41.648151356Z [Fri Sep 12 18:17:41 UTC 2025] Installing full chain to: /certs/insulon.rymcg.tech/fullchain.cer
acme-sh-1  | 2025-09-12T18:17:41.657532140Z [Fri Sep 12 18:17:41 UTC 2025] Running reload cmd: touch '/traefik/restart_me'
acme-sh-1  | 2025-09-12T18:17:41.669247971Z [Fri Sep 12 18:17:41 UTC 2025] Reload successful
acme-sh-1  | 2025-09-12T18:17:41.677056823Z [entrypoint:acme-sh] Certificate details for insulon.rymcg.tech:
acme-sh-1  | 2025-09-12T18:17:41.727222044Z   notBefore=Sep 12 17:19:10 2025 GMT
acme-sh-1  | 2025-09-12T18:17:41.735464637Z   notAfter=Dec 11 17:19:09 2025 GMT
acme-sh-1  | 2025-09-12T18:17:41.735523096Z   issuer=C=US, O=Let's Encrypt, CN=E8
acme-sh-1  | 2025-09-12T18:17:41.735529514Z   subject=CN=insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:41.735534692Z   X509v3 Subject Alternative Name:
acme-sh-1  | 2025-09-12T18:17:41.735540318Z       DNS:*.insulon.rymcg.tech, DNS:insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:41.736623193Z [entrypoint:acme-sh] Installed files under: /certs/insulon.rymcg.tech
acme-sh-1  | 2025-09-12T18:17:41.739492248Z + exec crond -n -s -m off
```

## whoami

Install whoami as a test to use the certificate:

```bash
$ d make whoami config

Configuring environment file: .env_insulon_default
WHOAMI_TRAEFIK_HOST: Enter the whoami domain name (eg. whoami.example.com)
: whoami.insulon.rymcg.tech

> Do you want to enable sentry authorization in front of this app (effectively making the entire site private)? No

$ d make whoami install
```

### Check the TLS cert is correctly used

```bash
d script tls_debug whoami.insulon.rymcg.tech
```

This will connect to your whoami service and print information about the TLS certificate. The important bit to watch for is this:

```text
---
Certificate chain
 0 s:CN=insulon.rymcg.tech
   i:C=US, O=Let's Encrypt, CN=E8
   a:PKEY: id-ecPublicKey, 256 (bit); sigalg: ecdsa-with-SHA384
   v:NotBefore: Sep 12 17:19:10 2025 GMT; NotAfter: Dec 11 17:19:09 2025 GMT
 1 s:C=US, O=Let's Encrypt, CN=E8
   i:C=US, O=Internet Security Research Group, CN=ISRG Root X1
   a:PKEY: id-ecPublicKey, 384 (bit); sigalg: RSA-SHA256
   v:NotBefore: Mar 13 00:00:00 2024 GMT; NotAfter: Mar 12 23:59:59 2027 GMT
---
```

This shows that Let's Encrypt issued the certificate and the validity period.


## Whoami

## Forgejo

## Traefik-Forward-Auth

## Postfix Relay

## Step-CA (and acme-dns)
## Docker Registry

## SFTP (and Thttpd)

## MinIO S3 (and Filestash)

## Homepage

## Nginx and PHP

## Jupyterlab
