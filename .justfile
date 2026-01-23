# claylo-rs template development justfile
# Run `just` to see available recipes

# Default recipe: show help
default:
    @just --list

# Test all template presets
test:
    ./scripts/test-template.sh

# Test a specific preset (minimal, standard, standard-otel, full)
test-preset preset:
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

# Start Docker testing services (OTEL stack, etc.)
docker-up:
    docker compose -f scripts/docker/docker-compose.yml up -d

# Stop Docker testing services
docker-down:
    docker compose -f scripts/docker/docker-compose.yml down

# Tail Docker service logs
docker-logs:
    docker compose -f scripts/docker/docker-compose.yml logs -f

# Check Docker service status
docker-status:
    docker compose -f scripts/docker/docker-compose.yml ps
