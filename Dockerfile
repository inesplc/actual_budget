FROM docker.io/actualbudget/actual-server:latest

# Heroku uses PORT environment variable
ENV ACTUAL_PORT=$PORT

# Expose the port (Heroku will assign this dynamically)
EXPOSE $PORT

# The base image already has the correct CMD, but we'll make sure
CMD ["node", "src/app.js"]