#!/bin/sh
echo "Starting setup_sync.sh"

# Sync data from R2 to local /app/data directory
# This ensures that the latest data is available before starting
echo "Syncing data from R2 to /app/data from key ${CLOUDFLARE_ACCOUNT_ID}"
s3cmd --access_key="${CLOUDFLARE_R2_KEY_ID}" \
      --secret_key="${CLOUDFLARE_R2_SECRET_KEY}" \
      --host="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      --host-bucket="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      sync s3://actual-budget/data /app
echo "Data sync complete"

CRON_FILE="/usr/local/bin/cronjobs"

if [ -f "$CRON_FILE" ]; then
      echo "Starting supercronic with $CRON_FILE"
      supercronic "$CRON_FILE" &
else
      echo "Cron file $CRON_FILE not found; skipping supercronic startup"
fi

