#!/bin/sh
echo "Starting setup_sync.sh"

# Remove existing .migrate file if it exists
rm -f /app/data/.migrate
touch /app/data/.migrate
chown 1001:1001 /app/data/.migrate

# Sync data from R2 to local /app/data directory
# This ensures that the latest data is available before starting
s3cmd --access_key="${CLOUDFLARE_R2_KEY_ID}" \
      --secret_key="${CLOUDFLARE_R2_SECRET_KEY}" \
      --host="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      --host-bucket="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      sync s3://actual-budget/data/ /app/data/
echo "Data sync complete"

CRON_FILE="/usr/local/bin/cronjobs"

if [ -f "$CRON_FILE" ]; then
      echo "Starting supercronic with $CRON_FILE"
      supercronic "$CRON_FILE" >> /var/log/supercronic.log 2>&1 &
else
      echo "Cron file $CRON_FILE not found; skipping supercronic startup"
fi
