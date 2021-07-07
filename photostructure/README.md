## Photostructure

[Photostructure](https://photostructure.com/server/photostructure-for-servers/)
is a personal digital asset manager designed to make organizing, browsing,
and sharing a lifetime of photos and videos effortless and fun.
Photostructure is *not* open-source.

SSH to the host, then:
- Create a new user: `sudo adduser psuser`.
  - Learn what UID and GID `psuser` was assigned to:
  ```cat /etc/passwd | grep psuser```
  - Use these values for UID and GID in your .env file, and when changing ownership, below.
- Mount external volume for persistent storage (e.g., certificates, system settings).
  - Use this mount-point for PS_LIBRARY_PATH in your .env file. 
- Mount an external volume or S3 space for your asset storage (photos and videos).
  - Use this mount-point for ASSET_DIR_HOST in your .env file. 
- Change ownership of the persistent storage and the asset mount-points:
  e.g.:
  ```
  chown -R 1000:1000 /mnt/ps_assets /mnt/ps_config
  ``` (You only need to do this once, ever: once you set it, it's in the inode for the directory -
  i.e., the owner stays with the directory wherever it is mounted).
- Edit `/etc/fstab` to auto-mount the persistent storage and the asset mount-points on boot.

Copy `.env-dist` to `.env`, and edit variables accordingly. Find explanations
of Photostructure environment variables [here](https://github.com/photostructure/photostructure-for-servers/blob/main/defaults.env).

 * `PHOTOSTRUCTURE_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `BASICAUTH_USERS` Copy the result of the following command (replacing USERNAME and PASSWORD with the login and
password you want to use for Photostructure): `htpasswd -nb USERNAME PASSWORD | sed -e s/\\$/\\$\\$/g | grep .`

To start Photostructure, go into the photostructure directory and run `docker-compose up -d`. 

- On first launch of the Photostructure webpage, select "No thanks, I like my photos and videos where they already are" and click "Start".