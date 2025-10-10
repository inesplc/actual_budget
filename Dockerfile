FROM docker.io/actualbudget/actual-server:latest

RUN mkdir -p /data && chown -R 1001:1001 /data

# Use a shell script to set the port at runtime
# CMD sh -c 'export ACTUAL_PORT=$PORT && node src/app.js'
CMD sh -c 'node src/app.js'