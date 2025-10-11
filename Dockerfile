FROM docker.io/actualbudget/actual-server:latest

ENV ACTUAL_DATA_DIR=/app/data
ENV ACTUAL_HOSTNAME=0.0.0.0

RUN mkdir -p "$ACTUAL_DATA_DIR" "$ACTUAL_DATA_DIR/server-files" "$ACTUAL_DATA_DIR/user-files" \
	&& chown -R 1001:1001 "$ACTUAL_DATA_DIR"

RUN apt-get update && apt-get -y install cron s3cmd



CMD ["node", "app.js"]