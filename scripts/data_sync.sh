#!/bin/sh
set -eu

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting data_sync.sh as $(id -un) (uid=$(id -u), gid=$(id -g))"

# Use flock to prevent concurrent executions
exec 9>/tmp/data_sync.lock
if ! flock -n 9; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Another instance is running, exiting."
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Syncing $ACTUAL_DATA_DIR/ to R2..."
s3cmd --delete-removed sync "$ACTUAL_DATA_DIR/" s3://actual-budget/data/ 2>&1
echo "$(date '+%Y-%m-%d %H:%M:%S') - Data sync complete"