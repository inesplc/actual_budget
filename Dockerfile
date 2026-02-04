FROM docker.io/actualbudget/actual-server:latest

ENV SCRIPTS_DIR=/scripts
ENV LOGS_DIR=/logs
ENV ACTUAL_DATA_DIR=/app/data
ENV ACTUAL_HOSTNAME=0.0.0.0

# Setup data directory at build-time (no-op on Heroku but kept for local runs)
RUN mkdir -p "$ACTUAL_DATA_DIR" "$ACTUAL_DATA_DIR/server-files" "$ACTUAL_DATA_DIR/user-files" \
	&& chmod -R 0777 "$ACTUAL_DATA_DIR"

# Install curl, s3cmd, util-linux (for flock), and Python
RUN apt-get update \
	&& apt-get -y install curl s3cmd util-linux python3 python3-pip python3-venv \
	&& rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip3 install uv --break-system-packages

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
COPY scripts $SCRIPTS_DIR
# Ensure the scripts are executable
RUN chmod +x $SCRIPTS_DIR/*.sh

# Install Node.js dependencies for scripts
RUN cd $SCRIPTS_DIR/actual_api && npm install

# Install Python dependencies
RUN cd $SCRIPTS_DIR/enable_banking && uv sync

RUN mkdir -p $LOGS_DIR && touch $LOGS_DIR/supercronic.log

CMD ["sh", "-c", "$SCRIPTS_DIR/setup_sync.sh && node app.js"]