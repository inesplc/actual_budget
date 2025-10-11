FROM docker.io/actualbudget/actual-server:latest

ENV ACTUAL_DATA_DIR=/app/data
ENV ACTUAL_HOSTNAME=0.0.0.0

# Setup data directory
RUN mkdir -p "$ACTUAL_DATA_DIR" "$ACTUAL_DATA_DIR/server-files" "$ACTUAL_DATA_DIR/user-files" \
	&& chown -R 1001:1001 "$ACTUAL_DATA_DIR"

# Install cron and s3cmd
RUN apt-get update \
	&& apt-get -y install cron s3cmd \
	&& rm -rf /var/lib/apt/lists/*

# Add data sync script
COPY scripts/setup_sync.sh /usr/local/bin/setup_sync.sh
RUN chmod +x /usr/local/bin/setup_sync.sh
COPY scripts/cronjobs /usr/local/bin/cronjobs

CMD ["sh", "-c", "/usr/local/bin/setup_sync.sh && node app.js"]