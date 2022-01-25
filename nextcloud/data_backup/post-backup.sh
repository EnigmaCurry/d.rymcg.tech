#!/bin/sh

CONFIG=/data/config/config.php

# https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html
sed -i "s/'maintenance' => true,/'maintenance' => false,/" ${CONFIG}
echo "Disabled maintenance mode"
