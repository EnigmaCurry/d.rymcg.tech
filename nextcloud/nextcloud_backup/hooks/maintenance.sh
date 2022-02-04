#!/bin/sh

CONFIG=/data/config/config.php

# https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html
if [[ $1 == 'off' ]]; then
    sed -i "s/'maintenance' => true,/'maintenance' => false,/" ${CONFIG}
    echo "Disabled maintenance mode"
else
    if grep "maintenance" $CONFIG >/dev/null; then
        # Modify the existing maintenance line:
        sed -i "s/'maintenance' => false,/'maintenance' => true,/" ${CONFIG}
    else
        # Add a new maintenance line at the bottom:
        sed -i 's/^);$/  '\''maintenance'\'' => true,\n);/' ${CONFIG}
    fi
    echo "Enabled maintenance mode"
fi
