#!/bin/sh
set -eu

echo "Starting setup_sync.sh as $(id -un) (uid=$(id -u), gid=$(id -g))"
echo "Existing contents of /app/data:"
ls -al /app/data || echo "Unable to list /app/data"

# Clear existing local data so the sync can recreate everything cleanly
echo "Clearing /app/data before sync"
find /app/data -mindepth 1 -maxdepth 1 -exec sh -c 'echo "Removing $1"; rm -rf "$1"' _ {} \;
echo "Contents of /app/data after clear:"
ls -al /app/data || echo "Unable to list /app/data after clear"

# Sync data from R2 to local /app/data directory
# This ensures that the latest data is available before starting
echo "Syncing data from R2 to /app/data"
s3cmd --access_key="${CLOUDFLARE_R2_KEY_ID}" \
      --secret_key="${CLOUDFLARE_R2_SECRET_KEY}" \
      --host="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      --host-bucket="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      sync s3://actual-budget/data/ /app/data/
echo "Data sync complete"
echo "Contents of /app/data after sync:"
ls -al /app/data || echo "Unable to list /app/data after sync"

CRON_FILE="/usr/local/bin/cronjobs"

if [ -f "$CRON_FILE" ]; then
      echo "Starting supercronic with $CRON_FILE"
      supercronic "$CRON_FILE" >> /var/log/supercronic.log 2>&1 &
else
      echo "Cron file $CRON_FILE not found; skipping supercronic startup"
fi
