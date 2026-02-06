# claylo-rs template development justfile
# Run `just` to see available recipes
# Bats with agents formatter (reduced output for LLM context windows)

bats := "./test/bats/bin/bats -F $(pwd)/test/formatters/agents.bash"

# Default recipe: show help
default:
    @just --list

# Run all bats tests (conditional + presets)
test:
    {{ bats }} test/

# Run wrapper script tests only
test-wrapper:
    {{ bats }} test/wrapper.bats

# Run fast conditional file tests only
test-fast:
    {{ bats }} test/conditional_files.bats

# Run slow preset build tests only
test-presets:
    {{ bats }} test/presets.bats

# Run progressive enhancement tests (very slow - multiple cargo builds per test)
test-progressive:
    {{ bats }} test/progressive.bats

# Run a specific bats test file
test-file file:
    {{ bats }} {{ file }}

# Clean up test outputs
clean:
    rm -rf target/template-tests

# Regenerate code from preset YAML files
sync-presets:
    ./scripts/sync-presets

# Check if preset-generated code is in sync (for CI)
check-presets:
    ./scripts/sync-presets --check

# Generate a project interactively for manual testing
generate output_dir:
    copier copy --trust . {{ output_dir }}

# Generate using a data file
generate-from-file data_file output_dir:
    copier copy --trust --data-file {{ data_file }} . {{ output_dir }}

# Generate a test with the given preset
generate-preset preset project_name:
    copier copy --data "project_name={{ project_name }}" \
      --data "owner=test-owner" \
      --data "copyright_name=Test Copyright" \
      --data "conduct_email=conduct@test.org" \
      --defaults --data-file "scripts/presets/{{ preset }}.yml" \
      --vcs-ref HEAD . ../generate-runs/{{ project_name }}

regenerate-preset preset project_name:
    copier recopy --skip-answered --answers-file .repo.yml --overwrite --defaults \
      --data-file "scripts/presets/{{ preset }}.yml" \
      --vcs-ref HEAD ../generate-runs/{{ project_name }}

# Lint copier.yaml (using Python yamllint; yamllint-rs has sequence indent bug)
lint:
    yamllint -c .yamllint copier.yaml

# Format copier.yaml
fmt:
    yamlfmt -no_global_conf -conf .yamlfmt -quiet copier.yaml

# Validate template syntax (dry run)
validate:
    @echo "Validating template syntax..."
    copier copy --trust --defaults --pretend . target/template-validate 2>&1 || true
    @echo "Template syntax validation complete"

# Update copier in uv tools
update-copier:
    uv tool install copier --upgrade

# Scan for projects that can be updated from this template
scan-updates root:
    ./scripts/update-projects.sh {{ root }}

# Apply template updates to projects (creates branches)
apply-updates root:
    ./scripts/update-projects.sh -u {{ root }}

# =============================================================================
# Docker-based testing infrastructure
# =============================================================================

# Run bash coverage for wrapper tests (requires Docker)
test-coverage:
    @rm -rf bin/coverage
    docker compose -f scripts/docker/docker-compose.yml --profile coverage run --rm bashcov
    @echo ""
    @echo "Coverage report: bin/coverage/index.html"

# Start Docker testing services (OTEL stack)
docker-up:
    docker compose -f scripts/docker/docker-compose.yml up -d otel-lgtm

# Stop Docker testing services
docker-down:
    docker compose -f scripts/docker/docker-compose.yml down

# Tail Docker service logs
docker-logs:
    docker compose -f scripts/docker/docker-compose.yml logs -f

# Check Docker service status
docker-status:
    docker compose -f scripts/docker/docker-compose.yml ps

# =============================================================================
# OTEL Integration Tests
# =============================================================================

# Run OTEL integration tests (requires docker-up first)
test-otel:
    @echo "Checking OTEL collector status..."
    @curl -s --connect-timeout 2 http://localhost:3000/api/health > /dev/null || (echo "OTEL stack not running. Start with: just docker-up" && exit 1)
    @echo "Running OTEL tests..."
    {{ bats }} test/otel.bats

# Run OTEL tests with Docker stack (starts stack, runs tests, keeps stack running)
test-otel-docker:
    @echo "Starting OTEL stack..."
    docker compose -f scripts/docker/docker-compose.yml up -d otel-lgtm
    @echo "Waiting for OTEL stack to be healthy..."
    @until curl -s --connect-timeout 2 http://localhost:3000/api/health > /dev/null; do sleep 2; done
    @echo "Running OTEL tests..."
    {{ bats }} test/otel.bats

# Full test suite including OTEL (slow - builds presets, requires Docker)
test-full:
    @echo "Running conditional file tests..."
    {{ bats }} test/conditional_files.bats
    @echo ""
    @echo "Running preset build tests..."
    {{ bats }} test/presets.bats
    @echo ""
    @echo "Running OTEL integration tests..."
    just test-otel-docker

# =============================================================================
# Local crates.io Registry (for testing cargo publish workflows)
# =============================================================================
# The local registry is managed separately. See: https://github.com/claylo/crates-io-local
#
# Quick start:
#   cd ~/source/claylo/crates-io-local && docker compose up -d
#
# Publishing to local registry:
#   cargo publish --registry local --token test-token

# Run crates.io publish tests (requires local registry running)
test-publish:
    @echo "Checking local registry status..."
    @curl -s --connect-timeout 2 http://localhost:8888/api/v1/summary > /dev/null || (echo "Registry not running. See: https://github.com/claylo/crates-io-local" && exit 1)
    @echo "Running publish tests..."
    {{ bats }} test/publish.bats
