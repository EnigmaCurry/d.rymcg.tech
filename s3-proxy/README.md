# s3-proxy

[s3-proxy](https://github.com/oxyno-zeta/s3-proxy) is an HTTP proxy for Amazon
S3 (compatible) services. This allows your regular web clients to upload and
download content in S3 buckets. HTTP indexes are created for directories, so you
can easily list your buckets from your web browser.

Consider installing [minio](../minio) as a self-hosted S3 server to test in,
follow the instructions there for creating a bucket and user credentials. Put
these into your `.env` file.

## Limiting traffic

You can limit traffic based on source IP address by expressing a [CIDR ip range
filter](https://doc.traefik.io/traefik/middlewares/tcp/ipwhitelist/).

Allow all IP ranges:

```
SOURCERANGE="0.0.0.0/0"
```

Allow only a single subnet:

```
SOURCERANGE="192.168.1.1/24"
```

Allow only a specific IP address:

```
SOURCERANGE="127.0.0.1/32"
```

You can specify multiple if you use a comma to separate them:

```
SOURCERANGE="127.0.0.1/32,192.168.1.1/24"
```

