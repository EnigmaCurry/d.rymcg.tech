# Nextcloud

[Nextcloud](https://nextcloud.com/) is an on-premises content collaboration
platform.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `NEXTCLOUD_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MYSQL_PASSWORD` you must choose a secure password for the database.

To start Nextcloud, go into the nextcloud directory and run `docker-compose up -d`.

Visit the configured domain name in your browser to finish the installation.
Choose MySQL/MariaDB for the database, enter the details:

 * Username: nextcloud
 * Database: nextcloud
 * Database host: mariadb
 * Password: same as you configured in .env `MYSQL_PASSWORD`
 
