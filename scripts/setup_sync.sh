#!/bin/sh
# Ensure cron daemon is running in the background
cron

# Sync data from R2 to local /app/data directory
# This ensures that the latest data is available before starting
s3cmd --access_key="${CLOUDFLARE_R2_KEY_ID}" \
      --secret_key="${CLOUDFLARE_R2_SECRET_KEY}" \
      --host="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      --host-bucket="${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      sync s3://actual-budget/data /app/data


# Create cron jobs from the specified file if it exists
CRON_SOURCE="/usr/local/bin/cronjobs"

if [ -f "$CRON_SOURCE" ]; then
  crontab "$CRON_SOURCE"
fi
