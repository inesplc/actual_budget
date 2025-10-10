FROM docker.io/actualbudget/actual-server:latest

# Expose the port (Heroku will assign this dynamically)
EXPOSE 5006

# Use a shell script to set the port at runtime
CMD sh -c 'export ACTUAL_PORT=${PORT:-5006} && node src/app.js'