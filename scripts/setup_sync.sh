#!/bin/sh
set -eu

echo "Starting setup_sync.sh as $(id -un) (uid=$(id -u), gid=$(id -g))"
echo "Using data directory: $ACTUAL_DATA_DIR"

rm -rf "$ACTUAL_DATA_DIR"

# mkdir -p "$ACTUAL_DATA_DIR" "$ACTUAL_DATA_DIR/server-files" "$ACTUAL_DATA_DIR/user-files"
# chmod -R 0777 "$ACTUAL_DATA_DIR"

# Sync data from R2 to local /app/data directory
# This ensures that the latest data is available before starting
echo "Syncing data from R2 to $ACTUAL_DATA_DIR"
s3cmd --access_key="${CLOUDFLARE_R2_KEY_ID}" \
      --secret_key="${CLOUDFLARE_R2_SECRET_KEY}" \
      --host="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      --host-bucket="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      sync s3://actual-budget/data "$ACTUAL_DATA_DIR/"
echo "Data sync complete"
echo "Contents of $ACTUAL_DATA_DIR after sync:"
ls -al "$ACTUAL_DATA_DIR" || echo "Unable to list $ACTUAL_DATA_DIR after sync"

CRON_FILE="/usr/local/bin/cronjobs"

if [ -f "$CRON_FILE" ]; then
      echo "Starting supercronic with $CRON_FILE"
      supercronic "$CRON_FILE" >> /var/log/supercronic.log 2>&1 &
else
      echo "Cron file $CRON_FILE not found; skipping supercronic startup"
fi
