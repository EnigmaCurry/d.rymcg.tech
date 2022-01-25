FROM localhost/nextcloud-restic-backup
COPY pre-backup.sh /hooks/pre-backup.sh
COPY post-backup.sh /hooks/post-backup.sh
COPY maintenance.sh /hooks/maintenance.sh
RUN chmod a+x /hooks/pre-backup.sh /hooks/post-backup.sh /hooks/maintenance.sh
