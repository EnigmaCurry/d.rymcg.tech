# Syncthing

[Syncthing](https://hub.docker.com/r/syncthing/syncthing) is a continuous file
synchronization program.

Copy `.env-dist` to `.env` and edit the variables accordingly, though the
default values are probably fine.

To start Syncthing, go into the syncthing directory and run `docker-compose up -d`.

To access the Syncthing GUI:
1. Create a tunnel:
   ```
   ssh -L 8384:localhost:8384 root@your.remotehost.com
   ```
2. Visit http://localhost:8384 in a web browser.
