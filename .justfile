# claylo-rs template development justfile
# Run `just` to see available recipes

# Default recipe: show help
default:
    @just --list

# Run all bats tests (conditional + presets)
test:
    ./test/bats/bin/bats test/

# Run fast conditional file tests only
test-fast:
    ./test/bats/bin/bats test/conditional_files.bats

# Run slow preset build tests only
test-presets:
    ./test/bats/bin/bats test/presets.bats

# Run a specific bats test file
test-file file:
    ./test/bats/bin/bats {{ file }}

# Run legacy test script (deprecated, use 'just test' instead)
test-legacy:
    ./scripts/test-template.sh

# Run legacy test for a specific preset
test-legacy-preset preset:
    ./scripts/test-template.sh {{ preset }}

# Clean up test outputs
clean:
    rm -rf target/template-tests

# Generate a project interactively for manual testing
generate output_dir:
    copier copy --trust . {{ output_dir }}

# Generate using a data file
generate-from-file data_file output_dir:
    copier copy --trust --data-file {{ data_file }} . {{ output_dir }}

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
    ./test/bats/bin/bats test/otel.bats

# Run OTEL tests with Docker stack (starts stack, runs tests, keeps stack running)
test-otel-docker:
    @echo "Starting OTEL stack..."
    docker compose -f scripts/docker/docker-compose.yml up -d otel-lgtm
    @echo "Waiting for OTEL stack to be healthy..."
    @until curl -s --connect-timeout 2 http://localhost:3000/api/health > /dev/null; do sleep 2; done
    @echo "Running OTEL tests..."
    ./test/bats/bin/bats test/otel.bats

# Full test suite including OTEL (slow - builds presets, requires Docker)
test-full:
    @echo "Running conditional file tests..."
    ./test/bats/bin/bats test/conditional_files.bats
    @echo ""
    @echo "Running preset build tests..."
    ./test/bats/bin/bats test/presets.bats
    @echo ""
    @echo "Running OTEL integration tests..."
    just test-otel-docker

# =============================================================================
# Local crates.io Registry (for testing cargo publish workflows)
# =============================================================================
# Uses the official crates.io codebase as a submodule in test/crates-io
# with custom configuration in test/registry/
#
# Quick start (uses pre-built GHCR images):
#   just registry-up
#
# Build locally instead (slow, ~10 min first time):
#   just registry-build
#   just registry-up
#
# Publishing to local registry:
#   cargo publish --index http://localhost:8888/git/index --token test-token

# Start local crates.io registry (uses pre-built images if available)
registry-up:
    @echo "Starting local crates.io registry..."
    @if [ -f test/registry/docker-compose.override.yml ]; then \
        echo "  Using pre-built images from GHCR"; \
        cd test/registry && docker compose pull --quiet 2>/dev/null || true; \
    else \
        echo "  Building locally (this may take a while)"; \
    fi
    cd test/registry && docker compose up -d
    @echo ""
    @echo "Waiting for services to be ready (may take 1-5 min on first run)..."
    @until curl -s --connect-timeout 2 http://localhost:8888/api/v1/summary > /dev/null 2>&1; do sleep 3; echo "  waiting..."; done
    @echo ""
    @echo "Local crates.io registry is ready!"
    @echo "  Backend API:  http://localhost:8888"
    @echo "  Frontend UI:  http://localhost:4200"
    @echo "  Git index:    http://localhost:8888/git/index"
    @echo ""
    @echo "To publish a crate:"
    @echo "  cargo publish --index http://localhost:8888/git/index --token test-token"

# Pull pre-built registry images from GHCR
registry-pull:
    @echo "Pulling pre-built images from GHCR..."
    cd test/registry && docker compose pull

# Build registry images locally (slow, ~10 min)
registry-build:
    @echo "Building registry images locally..."
    @if [ -f test/registry/docker-compose.override.yml ]; then \
        mv test/registry/docker-compose.override.yml test/registry/docker-compose.override.yml.disabled; \
        echo "  Disabled override file for local build"; \
    fi
    cd test/registry && docker compose build

# Enable pre-built images (restore override file)
registry-use-prebuilt:
    @if [ -f test/registry/docker-compose.override.yml.disabled ]; then \
        mv test/registry/docker-compose.override.yml.disabled test/registry/docker-compose.override.yml; \
        echo "Pre-built images enabled"; \
    else \
        echo "Already using pre-built images"; \
    fi

# Stop local crates.io registry
registry-down:
    cd test/registry && docker compose down

# Tail crates.io logs
registry-logs:
    cd test/registry && docker compose logs -f

# Check crates.io status
registry-status:
    @cd test/registry && docker compose ps
    @echo ""
    @if [ -f test/registry/docker-compose.override.yml ]; then \
        echo "Mode: pre-built images (GHCR)"; \
    else \
        echo "Mode: local build"; \
    fi

# Restart crates.io backend (after code changes)
registry-restart:
    cd test/registry && docker compose restart backend worker

# Reset crates.io database (destructive - removes all data)
registry-reset:
    @echo "This will delete all registry data. Press Ctrl+C to cancel..."
    @sleep 3
    cd test/registry && docker compose down -v
    @echo "Registry data cleared. Run 'just registry-up' to start fresh."

# Run crates.io publish tests
test-publish:
    @echo "Checking local registry status..."
    @curl -s --connect-timeout 2 http://localhost:8888/api/v1/summary > /dev/null || (echo "Registry not running. Start with: just registry-up" && exit 1)
    @echo "Running publish tests..."
    ./test/bats/bin/bats test/publish.bats
