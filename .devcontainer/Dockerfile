# Node.js runtime source.
# Avoid NodeSource installation scripts, which may fail behind some proxies.
FROM node:22.13.1-slim AS node_runtime

FROM ruby:4.0-slim

# Install Rails, PostgreSQL and development dependencies.
RUN set -eux; \
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i 's|http://deb.debian.org|https://deb.debian.org|g' \
            /etc/apt/sources.list.d/debian.sources; \
    fi; \
    if [ -f /etc/apt/sources.list ]; then \
        sed -i 's|http://deb.debian.org|https://deb.debian.org|g' \
            /etc/apt/sources.list; \
    fi; \
    apt-get update -o Acquire::Retries=5; \
    DEBIAN_FRONTEND=noninteractive apt-get install \
        --no-install-recommends -y \
        build-essential \
        ca-certificates \
        curl \
        git \
        libyaml-dev \
        pkg-config \
        libpq-dev \
        postgresql-client \
        sqlite3 \
        libsqlite3-dev \
        libvips \
        libjemalloc2; \
    ln -sf "/usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2" \
        /usr/local/lib/libjemalloc.so; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy Node.js and bundled package managers from the official Node image.
COPY --from=node_runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node_runtime /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node_runtime /opt /opt

# Restore npm, npx and Yarn command links, then verify all tools.
RUN set -eux; \
    ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm; \
    ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx; \
    yarn_dir="$(find /opt -maxdepth 1 -type d -name 'yarn-v*' | head -n 1)"; \
    test -n "${yarn_dir}"; \
    ln -sf "${yarn_dir}/bin/yarn" /usr/local/bin/yarn; \
    ln -sf "${yarn_dir}/bin/yarnpkg" /usr/local/bin/yarnpkg; \
    node --version; \
    npm --version; \
    yarn --version; \
    psql --version; \
    pg_isready --version

# Pre-create expected Rails directories.
RUN mkdir -p /workspace/storage /workspace/log /workspace/tmp/pids

ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle

# Create the Dev Container user.
RUN useradd -m -s /bin/bash vscode && \
    chown -R vscode:vscode /usr/local/bundle /workspace
