## Photostructure

[Photostructure](https://photostructure.com/server/photostructure-for-servers/)
is a personal digital asset manager designed to make organizing, browsing, and sharing a lifetime of photos and videos effortless and fun. Photostructure is [*not* open-source](https://photostructure.com/legal/eula/).

### SSH to the host, then:
1. Create new user for Photostructure to use.
   ```
   sudo adduser psuser
   ```
   * Learn what UID and GID `psuser` was assigned to:
     ```
     cat /etc/passwd | grep psuser
     ```
2. Mount an external volume for your asset storage (photos and videos).
   * Use this mount-point for ASSET_DIR_HOST in your .env file.
   * Photostructure doesn't work with s3fs-mounted S3 storage, but [here](#photostructure-and-s3) were the instructions to set it up.
3. Change ownership of the asset mount-point, replacing UID and GID with the UID and GID of your Photostructure user from step 1, and ASSET_DIR_HOST with the mount-point from step 2:
   ```
   chown -R UID:GID ASSET_DIR_HOST
   ```
   (You only need to do this once, ever: once you set it, it's in the inode for the directory - i.e., the owner stays with the directory wherever it is mounted).
4. Edit `/etc/fstab` to auto-mount the persistent storage and the asset mount-points on boot, replacing ASSET_DIR_HOST with the mount-point from step 2. THis example mounts a Digital Ocean volume in their nyc3 datacenter called volume-nyc1-01:
   ```
   echo '/dev/disk/by-id/scsi-0DO_Volume_volume-nyc1-01 ASSET_DIR_HOST ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab
   ```

### In your git clone directory:
#### Copy `.env-dist` to `.env`, and edit variables accordingly.
 * `PHOTOSTRUCTURE_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `BASICAUTH_USERS` Copy the result of the following command (replacing USERNAME and PASSWORD with the login and password you want to use for Photostructure):
    ```
    htpasswd -nb USERNAME PASSWORD
    ```
    You can repeat this command for multiple users, separating them in the .env file with a comma, e.g.:
    ```
    BASICAUTH_USERS=user1:encryptedPassword1,user2:encryptedPassword2
    ```
 * Find explanations of Photostructure environment variables [here](https://photostructure.com/faq/environment-variables) and [here](https://github.com/photostructure/photostructure-for-servers/blob/main/defaults.env).

#### To start Photostructure:
  * Go into the photostructure directory and run `docker-compose up -d`. 
  * On first launch of the Photostructure webpage, select "No thanks, I like my photos and videos where they already are" and click "Start".
  
  
### Photostructure and S3:
Photostructure doesn't work with s3fs-mounted S3 storage, but these were instructions to set everything up.

#### `ssh` to your host, then:
1. Install s3fs.
   ```
   apt install s3fs
   ```
2. Edit `/etc/fuse.conf` and uncomment the line `#user_allow_other` (or if that line doesn't exist, add the line `user_allow_other`).
   ```
   nano /ets/fuse.conf
   ```
3. Create new user for Photostructure to use.
   ```
   sudo adduser psuser
   ```
   * Learn what UID and GID `psuser` was assigned to:
     ```
     cat /etc/passwd | grep psuser
     ```
4. Create directory for mount-point, replacing ASSET_DIR_HOST with the mount-point created in [step 2, above](#ssh-to-the-host-then), and UID and GID with the UID and GID of your Photostructure user from step 3.
   ```
   mkdir -p ASSET_DIR_HOST
   chown UID:GID ASSET_DIR_HOST
   ```
5. Switch to the Photostructure user
   ```
   su psuser
   ```
6. Create s3fs password file, replacing KEY and SECRET with your S3 Key and Secret.
   ```
   echo KEY:SECRET | tee -a ${HOME}/.passwd-s3fs
   chmod 600 ${HOME}/.passwd-s3fs
   ```
7. Mount your S3 space, replacing SPACENAME with the name of your S3 space, ASSET_DIR_HOST with the mount-point created in [step 2, above](#ssh-to-the-host-then), ENDPOINT with your S3 endpoint, and UID and GID with the UID and GID of your Photostructure user from step 3.
   ```
   s3fs SPACENAME ASSET_DIR_HOST -o passwd_file=${HOME}/.passwd-s3fs -o url=https://ENDPOINT/ -o use_path_request_style -o allow_other`
   echo SPACENAME ASSET_DIR_HOST fuse.s3fs _netdev,allow_other,use_path_request_style,uid=UID,gid=GID,url=https://ENDPOINT/ 0 0 >> /etc/fstab
   ```
8. Create Photostructure's tmp directory, replacing TMP_DIR with the path to the temp directory that you use in your env file, and and UID and GID with the UID and GID of your Photostructure user from step 3.
   ```
   mkdir -p TMP_DIR
   chown -R UID:GID TMP_DIR
   ```
