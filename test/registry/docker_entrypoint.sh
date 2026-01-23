#!/bin/sh

# Custom entrypoint for local crates.io development
#
# Uses diesel.docker.toml instead of the default diesel.toml to avoid
# schema.patch application issues. The --config-file flag tells diesel
# to use our custom config which doesn't have a `file` setting, so it
# skips schema.rs regeneration entirely.

# If the backend is started before postgres is ready, the migrations will fail
until diesel migration run --config-file diesel.docker.toml; do
  echo "Migrations failed, retrying in 5 seconds..."
  sleep 5
done

./script/init-local-index.sh

cargo run
