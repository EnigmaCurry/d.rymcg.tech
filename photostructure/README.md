## Photostructure

[Photostructure](https://photostructure.com/server/photostructure-for-servers/)
is a personal digital asset manager designed to make organizing, browsing, and sharing a lifetime of photos and videos effortless and fun. Photostructure is *not* open-source.

### SSH to the host, then:
1. Create a new user: `sudo adduser psuser`.
   * Learn what UID and GID `psuser` was assigned to:
     ```
     cat /etc/passwd | grep psuser
     ```
   * Use these values for UID and GID in your .env file, and when changing ownership, below.
2. Mount external volume for persistent storage (e.g., certificates, system settings).
   * Use this mount-point for PS_LIBRARY_PATH in your .env file. 
3. [Mount an external volume or S3 space](#to-mount-an-s3-space) for your asset storage (photos and videos).
   * Use this mount-point for ASSET_DIR_HOST in your .env file. 
4. Change ownership of the persistent storage and the asset mount-points:
   e.g.:
   ```
   chown -R 1000:1000 /mnt/ps_assets /mnt/ps_config
   ```
   (You only need to do this once, ever: once you set it, it's in the inode for the directory - i.e., the owner stays with the directory wherever it is mounted).
5. Edit `/etc/fstab` to auto-mount the persistent storage and the asset mount-points on boot.

### To mount an S3 space:
  1. `apt install s3fs`
  2. `echo KEY:SECRET | sudo tee -a ${HOME}/.passwd-s3fs`
     * replace KEY and SECRET with your S3 Key and Secret
  3. `chmod 600 ${HOME}/.passwd-s3fs`
  4. `chown -R UID:GID ${HOME}/.passwd-s3fs`
     * replace UID and GID with the UID and GID that Photostructure uses, learned in step 1 [above](#ssh-to-the-host-then).
  5. `mkdir -p ASSET_DIR_HOST`
     * replace ASSET_DIR_HOST with the mount point used in step 3 [above](#ssh-to-the-host-then).
  6. `s3fs SPACENAME /mnt/ps_assets -o passwd_file=${HOME}/.passwd-s3fs -o url=https://ENDPOINT/ -o use_path_request_style`
     * replace SPACENAME with the name of your S3 space, and replace ENDPOINT with your S3 endpoint
  7. `echo SPACENAME /mnt/ps_assets fuse.s3fs _netdev,allow_other,use_path_request_style,uid=UID,gid=GID,url=https://ENDPOINT/ 0 0 >> /etc/fstab`
     * replace SPACENAME with the name of your S3 space, replace UID and GID with the UID and GID that Photostructure uses, learned in step 1 [above](#ssh-to-the-host-then), and replace ENDPOINT with your S3 endpoint
  8. `mkdir -p TMP_DIR`
     * replace TMP_DIR with the path to the temp directory that you use in your env file.
  9. `chown -R 1000:1000 TMP_DIR`
     * replace TMP_DIR with the path to the temp directory that you use in your env file.

### Copy `.env-dist` to `.env`, and edit variables accordingly.
 * `PHOTOSTRUCTURE_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `BASICAUTH_USERS` Copy the result of the following command (replacing USERNAME and PASSWORD with the login and password you want to use for Photostructure):
    ```
    htpasswd -nb USERNAME PASSWORD | sed -e s/\\$/\\$\\$/g | grep .
    ```
 * Find explanations of Photostructure environment variables [here](https://github.com/photostructure/photostructure-for-servers/blob/main/defaults.env).

### To start Photostructure:
  * Go into the photostructure directory and run `docker-compose up -d`. 
  * On first launch of the Photostructure webpage, select "No thanks, I like my photos and videos where they already are" and click "Start".