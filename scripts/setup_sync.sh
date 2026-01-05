#!/bin/sh
set -eu

echo "Starting setup_sync.sh as $(id -un) (uid=$(id -u), gid=$(id -g))"
echo "Using data directory: $ACTUAL_DATA_DIR"

# Generate s3cmd config
echo "Generating .s3cfg..."
cat > "$HOME/.s3cfg" <<EOF
[default]
access_key = ${CLOUDFLARE_R2_KEY_ID}
secret_key = ${CLOUDFLARE_R2_SECRET_KEY}
host_base = ${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com
host_bucket = ${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com
use_https = True
EOF

rm -rf "$ACTUAL_DATA_DIR/server-files/.*" "$ACTUAL_DATA_DIR/server-files/*"
rm -rf "$ACTUAL_DATA_DIR/user-files/.*" "$ACTUAL_DATA_DIR/user-files/*"
rm -rf "$ACTUAL_DATA_DIR/*"

chmod -R 0777 "$ACTUAL_DATA_DIR"

# Sync data from R2 to local /app/data directory
# This ensures that the latest data is available before starting
echo "Syncing data from R2 to $ACTUAL_DATA_DIR/"
s3cmd --no-preserve sync s3://actual-budget/data/ "$ACTUAL_DATA_DIR/" 2>&1
echo "Data sync complete"
echo "Contents of $ACTUAL_DATA_DIR after sync:"
ls -alR "$ACTUAL_DATA_DIR" || echo "Unable to list $ACTUAL_DATA_DIR after sync"

CRON_FILE="$SCRIPTS_DIR/crontab"

if [ -f "$CRON_FILE" ]; then
      echo "Starting supercronic with $CRON_FILE"
      supercronic "$CRON_FILE" &
else
      echo "Cron file $CRON_FILE not found; skipping supercronic startup"
fi
