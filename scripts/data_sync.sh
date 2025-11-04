#!/bin/sh
set -eu

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting data_sync.sh as $(id -un) (uid=$(id -u), gid=$(id -g))"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Syncing $ACTUAL_DATA_DIR to R2..."
s3cmd --access_key="$CLOUDFLARE_R2_KEY_ID" --secret_key="$CLOUDFLARE_R2_SECRET_KEY" --host="$CLOUDFLARE_ACCOUNT_ID".r2.cloudflarestorage.com --host-bucket="$CLOUDFLARE_ACCOUNT_ID".r2.cloudflarestorage.com sync $ACTUAL_DATA_DIR s3://actual-budget/data/ 2>&1
echo "$(date '+%Y-%m-%d %H:%M:%S') - Data sync complete"