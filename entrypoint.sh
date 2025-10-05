#!/bin/bash
set -e
# Shebang and error handling - script exists on error.

# Create master.key and link to RAILS_MASTER_KEY in .env file
if [ -n "${RAILS_MASTER_KEY}" ] && [ ! -f /rails/config/master.key ]; then
    echo "Creating master.key from environment variable..."
    echo "${RAILS_MASTER_KEY}" > /rails/config/master.key
    chmod 600 /rails/config/master.key
fi

# Remove a potentially pre-existing server.pid for Rails.
rm -f ./tmp/pids/server.pid

# Wait for database to be ready
echo "Waiting for database to be ready..."
until nc -z db 5432; do
  echo "Database not ready - sleeping"
  sleep 2
done

# Make sure db is ready to go
echo "Setting up database..."
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed

# Then exec the container's main process (CMD in the Dockerfile).
echo "Starting Rails server..."
exec "$@"