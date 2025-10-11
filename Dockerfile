FROM docker.io/actualbudget/actual-server:latest

ENV ACTUAL_DATA_DIR=/app/data

RUN mkdir -p "$ACTUAL_DATA_DIR" "$ACTUAL_DATA_DIR/server-files" "$ACTUAL_DATA_DIR/user-files" \
	&& chown -R 1001:1001 "$ACTUAL_DATA_DIR"

# Use a shell script to set the port and hostname at runtime
CMD ["sh", "-c", "ACTUAL_PORT=${PORT:-5006} ACTUAL_HOSTNAME=0.0.0.0 node src/app.js"]