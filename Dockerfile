# Defines a build-time variable with default value 3.2.2
ARG RUBY_VERSION=3.2.2

# Creates the base image using Ruby 3.2.2 slim container
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Set working directory
RUN mkdir -p /rails
WORKDIR /rails

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential netcat-openbsd curl git libpq-dev libvips pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set environment variables
ENV RAILS_ENV="development" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle"

# Creates everything needed to build app
FROM base as build

# Install build dependecies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git pkg-config libyaml-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}/ruby/*/cache" "${BUNDLE_PATH}/ruby/*/bundler/gems/*/.git" && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

# Final stage for app image
FROM base

# Copy built artifacts: gems, application, entrypoint
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails
COPY --from=build /usr/bin/entrypoint.sh /usr/bin/entrypoint.sh


# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p /rails/tmp/pids && \
    chown -R rails:rails /rails

# Switch to non-root user
USER 1000:1000

# Sets the entrypoint script that runs first
ENTRYPOINT ["/usr/bin/entrypoint.sh"]

# Start the application server
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
