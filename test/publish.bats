#!/usr/bin/env bats
# test/publish.bats
# Tests for crates.io publishing workflows
#
# Prerequisites:
#   just registry-up   # Start local crates.io registry
#
# Run with:
#   just test-publish

load 'test_helper'

# Local registry configuration
REGISTRY_URL="http://localhost:8888"
REGISTRY_INDEX="${REGISTRY_URL}/git/index"
# The local crates.io dev setup accepts any token
REGISTRY_TOKEN="test-token"

# Skip all tests if registry is not running
setup_file() {
    if ! curl -s --connect-timeout 2 "${REGISTRY_URL}/api/v1/summary" > /dev/null 2>&1; then
        skip "Local crates.io registry not running (start with: just registry-up)"
    fi
}

setup() {
    common_setup
}

# =============================================================================
# Registry Connectivity Tests
# =============================================================================

@test "local registry: API is accessible" {
    run curl -s "${REGISTRY_URL}/api/v1/summary"
    assert_success
}

@test "local registry: git index is accessible" {
    run curl -s "${REGISTRY_INDEX}/config.json"
    assert_success
}

# =============================================================================
# Publish Workflow Tests
# =============================================================================

@test "standard preset: cargo package succeeds" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard"

    # Generate if not already present
    if [[ ! -d "$output_dir" ]]; then
        output_dir=$(generate_project "preset-standard" "standard.yml")
    fi

    cd "$output_dir"

    # Package the CLI crate (dry run, don't actually publish)
    run cargo package -p test-standard --allow-dirty
    assert_success
}

@test "standard preset: cargo publish dry-run succeeds" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard"

    [[ -d "$output_dir" ]] || skip "standard preset not built"

    cd "$output_dir"

    # Dry run publish to local registry
    # Note: --dry-run validates the package without actually uploading
    run cargo publish -p test-standard \
        --index "$REGISTRY_INDEX" \
        --token "$REGISTRY_TOKEN" \
        --allow-dirty \
        --dry-run
    assert_success
}

@test "standard preset with core: publish order is correct (core first)" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard"

    [[ -d "$output_dir" ]] || skip "standard preset not built"

    cd "$output_dir"

    # The -core crate should be publishable first
    run cargo package -p test-standard-core --allow-dirty
    assert_success

    # Then the CLI crate (depends on core)
    run cargo package -p test-standard --allow-dirty
    assert_success
}

# =============================================================================
# Live Publish Tests (actually publishes to local registry)
# =============================================================================
# These tests modify the local registry state

@test "live publish: can publish test crate to local registry" {
    # Create a unique test crate to avoid conflicts
    local test_name="publish-test-$(date +%s)"
    local output_dir="${TEST_OUTPUT_DIR}/${test_name}"

    # Generate a minimal project with unique name
    rm -rf "$output_dir"
    mkdir -p "$output_dir"

    copier copy --trust --defaults \
        --data "project_name=${test_name}" \
        --data "owner=testorg" \
        --data "copyright_name=Test" \
        --data "preset=minimal" \
        --data "has_core_library=false" \
        --data "has_github=false" \
        --data "has_claude=false" \
        --data "has_just=false" \
        --data "has_agents_md=false" \
        --data "has_gitattributes=false" \
        --data "has_md=false" \
        --data "hook_system=none" \
        --data-file "${PROJECT_ROOT}/scripts/presets/minimal.yml" \
        "$PROJECT_ROOT" "$output_dir" >&2

    cd "$output_dir"

    # Build first to ensure it compiles
    run cargo build -p "$test_name"
    assert_success

    # Publish to local registry
    run cargo publish -p "$test_name" \
        --index "$REGISTRY_INDEX" \
        --token "$REGISTRY_TOKEN" \
        --allow-dirty
    assert_success

    # Verify the crate is now in the registry
    run curl -s "${REGISTRY_URL}/api/v1/crates/${test_name}"
    assert_success
    assert_output --partial "$test_name"
}
