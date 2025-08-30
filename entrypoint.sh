#!/bin/bash
set -e

DATA_DIR=${DATA_DIR:-/data/ca}
WWW_DIR=${WWW_DIR:-/var/www/html}

# ensure data dir exists
mkdir -p "$DATA_DIR"
chown -R www-data:www-data "$DATA_DIR"

# initialize CA structure if missing
if [ ! -f "$DATA_DIR/root/ca.crt" ]; then
  echo "Initializing CA structure..."
  /init_ca.sh "$DATA_DIR"
  echo "Initialization complete."
else
  echo "CA data found in $DATA_DIR, skipping initialization."
fi

# ensure PHP webfiles owned by www-data
chown -R www-data:www-data $WWW_DIR

# start supervisord to run services
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
