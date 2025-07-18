# Minio

[Minio](https://github.com/minio/minio) is an object storage server,
compatible with AWS S3 protocol.

This configuration is for a *single* server backed by a *single*
docker volume. So, **this is not a production-ready S3 service**, but
only intended for development or other light/unimportant storage
duties.

There are 2 ways you can manage your MinIO server:
 * OpenMaxIO is a web-based console that connects to MinIO and offers
  full adminsitrative functionality.
 * MinIO's `mc` command line client is a CLI tool offering full
  administrative functionality.
 * (MinIO also has its own web-based console, but it only offers
  limited functionality so it will not be installed).

## Config

```
make config
```

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

### Step-CA certificate

If you have enabled Traefik to use Step-CA as its certificate
resolver, you will need to configure the `mc` client to trust it.
Ensure you have the proper config in your minio
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file, and according to your
[step-ca](../step-ca) config:

```
## Minio Step-CA config:
MINIO_STEP_CA_ENABLED=true
MINIO_STEP_CA_ENDPOINT=https://ca.example.com
MINIO_STEP_CA_FINGERPRINT=xxxxxxxxxxx
```

This will add the Step-CA certificate to the trust store of the
utility `mc` container, allowing the `mc` client to trust the
certifcate and function properly. This is required for the console to
be installed, as it uses the `mc` client to create a user, and for
`make bucket` to work.

### Limiting traffic

You can limit traffic based on source IP address for MinIO and/or the
console, by expressing a [CIDR ip range
filter](https://doc.traefik.io/traefik/middlewares/tcp/ipallowlist/):

 * `S3_SOURCERANGE` - This is the IP address filter for
   `MINIO_TRAEFIK_HOST`
 * `CONSOLE_SOURCERANGE` - This is the IP address filter for
   `MINIO_CONSOLE_TRAEFIK_HOST`

## Install

Once your `.env_${DOCKER_CONTEXT}_{$INSTANCE}}` file is configured,
start the service:

```
make install
```

### Console Credentials

After you run `make install` and the MinIO server is running, run the
following command to create the access key, secret key, group, and
policy on the MinIO server that the console will use internally to
connect to MinIO:

```
make config-console
```

## Run

To launch the console in a web browser, run:

```
make open
```

## Create a bucket

The included `create_bucket_and_user.sh` BASH script will automate the
process of creating a bucket, creating a policy, adding a group and a
user, generating a secure secret key, and printing it all out to the
screen. Just answer the questions it asks and it will take care of
running the `mc` client (the Minio command line client) and issuing
all the commands. Watch the output to learn the exact commands it runs
to learn from it.

To invoke the script, run:

```
make bucket
```

You don't have to use this script, you can instead create everything
from the GUI console, following the instructions in the next section.

## Using Minio or the console to create bucket and credentials

The console is a web application that lets you graphically interact
with your MinIO instance. By default, all access is prevented by the
following configs in your `.env_{DOCKER_CONTEXT}_{INSTANCE}` file:

```
## The console is disabled if this is set to 0.0.0.0/32
## Change this to 0.0.0.0/0 to allow all ip addresses to access the console page:
CONSOLE_SOURCERANGE="0.0.0.0/32"
```

Log into the console (e.g., `https://console.s3.example.com`) using
the root user and the password you set in
`.env_${DOCKER_CONTEXT}_{INSTANCE}`.

Create a bucket:

 * Go to the `Buckets` page, click `Create Bucket`, choose a name for
   the bucket (eg. `videos`), click `Create Bucket`.

Create an IAM Policy for the group to access the bucket:

 * Go to `IAM Policies`, click `Create Policy`, choose a name for the
   policy (eg. `videos`), enter the following policy:


```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::videos"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": ["arn:aws:s3:::videos/*"]
    }
  ]
}
```

 * Edit the policy text and find the two references to `videos` and
   change these to the chosen name of your bucket.
 * Click `Save`

Create a group and assign the policy:

 * Go to the `Groups` page, click `Create Group`, choose a name for
   the group (eg. `videos`), click `Save`.
 * Click on the new group name in the list of groups.
 * Go to the `Policies` tab.
 * Click `Set Policies`.
 * Checkmark the policy name you created above.
 * Click `Save`.

Create a user, credentials, and assign to the group:

 * Go to the `Users` page, click `Create User`.
 * Make sure this form is blank before proceeding. (Your web browser
   may inadvertantly fill this form with the root password if you
   saved it in your browser password manager.)
 * Enter a unique Access key (ie. username; the easiest is to re-use
   the group name, eg. `videos`).
 * Enter a secure randomized Secret Key. (eg. use the output of
   `openssl rand -base64 45`)
 * Click on the `Groups` sub-tab, and add the group. (eg. `videos`)
 * *Do not* assign any policy directly to the user (it will inherit
   from the group instead).
 * Click `Save`

## Check out the s3-proxy

[s3-proxy](../s3-proxy) is another service you can deploy that is an
HTTP proxy for s3, so that regular web clients can access your S3
buckets.

