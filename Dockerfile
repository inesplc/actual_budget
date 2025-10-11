FROM docker.io/actualbudget/actual-server:latest

ENV ACTUAL_DATA_DIR=/app/data
ENV ACTUAL_HOSTNAME=0.0.0.0

RUN mkdir -p "$ACTUAL_DATA_DIR" "$ACTUAL_DATA_DIR/server-files" "$ACTUAL_DATA_DIR/user-files" \
	&& chown -R 1001:1001 "$ACTUAL_DATA_DIR"

RUN apt-get update \
	&& apt-get -y install cron s3cmd \
	&& rm -rf /var/lib/apt/lists/*

COPY cronjobs /etc/cron.d/actual-sync

RUN chmod 0644 /etc/cron.d/actual-sync \
	&& crontab /etc/cron.d/actual-sync

CMD ["sh", "-c", "cron && node app.js"]