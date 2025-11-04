FROM docker.io/actualbudget/actual-server:latest

ENV ACTUAL_DATA_DIR=/app/data
ENV ACTUAL_HOSTNAME=0.0.0.0

# Setup data directory at build-time (no-op on Heroku but kept for local runs)
RUN mkdir -p "$ACTUAL_DATA_DIR" "$ACTUAL_DATA_DIR/server-files" "$ACTUAL_DATA_DIR/user-files" \
	&& chmod -R 0777 "$ACTUAL_DATA_DIR"

# Install curl and s3cmd
RUN apt-get update \
	&& apt-get -y install curl s3cmd \
	&& rm -rf /var/lib/apt/lists/*

# Install supercronic
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.38/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=bc072eba2ae083849d5f86c6bd1f345f6ed902d0 \
    SUPERCRONIC=supercronic-linux-amd64

RUN curl -fsSLO "$SUPERCRONIC_URL" \
 && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
 && chmod +x "$SUPERCRONIC" \
 && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
 && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# Add data sync script
COPY scripts /usr/local/bin
# Ensure the scripts are executable
RUN chmod +x /usr/local/bin/*.sh

CMD ["sh", "-c", "ls -lha $ACTUAL_DATA_DIR && /usr/local/bin/setup_sync.sh && node app.js"]