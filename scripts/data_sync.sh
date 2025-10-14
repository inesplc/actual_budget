#!/bin/sh
set -eu

echo "Starting data_sync.sh as $(id -un) (uid=$(id -u), gid=$(id -g))"
s3cmd --access_key="$CLOUDFLARE_R2_KEY_ID" --secret_key="$CLOUDFLARE_R2_SECRET_KEY" --host="$CLOUDFLARE_ACCOUNT_ID".r2.cloudflarestorage.com --host-bucket="$CLOUDFLARE_ACCOUNT_ID".r2.cloudflarestorage.com sync /app/data/ s3://actual-budget/data/