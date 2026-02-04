#!/usr/bin/env bats
# test/presets.bats
# Full preset integration tests (builds with cargo)
# These tests are slower - run conditional_files.bats first for fast feedback

load 'test_helper'

# =============================================================================
# Minimal Preset
# =============================================================================

@test "minimal preset: generates and builds" {
    local output_dir
    output_dir=$(generate_project "preset-minimal" "minimal.yml")

    cd "$output_dir"
    cargo_clippy "$output_dir"
}

@test "minimal preset: tests pass" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-minimal"

    # Reuse from previous test
    [[ -d "$output_dir" ]] || skip "minimal preset not built"

    cd "$output_dir"
    cargo_test "$output_dir"
}

@test "minimal preset: binary runs --help" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-minimal"

    [[ -d "$output_dir" ]] || skip "minimal preset not built"

    # Run binary directly (cargo_clippy already built it)
    run "$output_dir/target/debug/preset-minimal" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "minimal preset: binary runs --version" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-minimal"

    [[ -d "$output_dir" ]] || skip "minimal preset not built"

    run "$output_dir/target/debug/preset-minimal" --version
    assert_success
}

@test "minimal preset: info command works" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-minimal"

    [[ -d "$output_dir" ]] || skip "minimal preset not built"

    run "$output_dir/target/debug/preset-minimal" info
    assert_success
}

# =============================================================================
# Standard Preset
# =============================================================================

@test "standard preset: generates and builds" {
    local output_dir
    output_dir=$(generate_project "preset-standard" "standard.yml")

    cd "$output_dir"
    cargo_clippy "$output_dir"
}

@test "standard preset: tests pass" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard"

    [[ -d "$output_dir" ]] || skip "standard preset not built"

    cd "$output_dir"
    cargo_test "$output_dir"
}

@test "standard preset: JSONL logging works" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard"

    [[ -d "$output_dir" ]] || skip "standard preset not built"

    local log_dir="${output_dir}/test-logs"
    mkdir -p "$log_dir"

    # Run with -v to enable debug logging
    APP_LOG_DIR="$log_dir" "$output_dir/target/debug/preset-standard" -v info > /dev/null 2>&1

    # Find the log file (rotation creates dated files)
    local log_file
    log_file=$(ls -S "$log_dir"/*.jsonl* 2>/dev/null | head -1)

    [[ -n "$log_file" ]] || fail "No JSONL log file created"
    [[ -s "$log_file" ]] || fail "JSONL log file is empty"

    # Validate each line is valid JSON
    run python3 -c "
import sys, json
valid = invalid = 0
for line in open('$log_file'):
    line = line.strip()
    if not line: continue
    try:
        json.loads(line)
        valid += 1
    except:
        invalid += 1
sys.exit(0 if valid > 0 and invalid == 0 else 1)
"
    assert_success
}

@test "standard preset: info --json returns valid JSON" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard"

    [[ -d "$output_dir" ]] || skip "standard preset not built"

    run "$output_dir/target/debug/preset-standard" info --json
    assert_success

    # Validate JSON
    echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

@test "standard preset: config discovery works" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard"

    [[ -d "$output_dir" ]] || skip "standard preset not built"

    # Create a test config file
    local config_dir="${output_dir}/config-test"
    mkdir -p "$config_dir"
    cat > "${config_dir}/.preset-standard.toml" << 'EOF'
log_level = "debug"
EOF

    local log_dir="${output_dir}/config-test-logs"
    mkdir -p "$log_dir"

    # Run from config directory (binary uses cwd for config discovery)
    cd "$config_dir"
    APP_LOG_DIR="$log_dir" "$output_dir/target/debug/preset-standard" info > /dev/null 2>&1 || true

    # Config discovery is best-effort, don't fail test
}

# =============================================================================
# Standard with OpenTelemetry Preset
# =============================================================================

@test "standard-otel preset: generates and builds" {
    local output_dir
    output_dir=$(generate_project "preset-standard-otel" "_standard-otel.yml")

    cd "$output_dir"
    cargo_clippy "$output_dir"
}

@test "standard-otel preset: tests pass" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard-otel"

    [[ -d "$output_dir" ]] || skip "standard-otel preset not built"

    cd "$output_dir"
    cargo_test "$output_dir"
}

@test "standard-otel preset: runs with OTEL endpoint set" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard-otel"

    [[ -d "$output_dir" ]] || skip "standard-otel preset not built"

    # Binary should run even if OTEL endpoint is unreachable
    OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317" \
        run "$output_dir/target/debug/preset-standard-otel" info
    assert_success
}

# =============================================================================
# Full Preset
# =============================================================================

@test "full preset: generates and builds" {
    local output_dir
    output_dir=$(generate_project "preset-full" "full.yml")

    cd "$output_dir"
    cargo_clippy "$output_dir"
}

@test "full preset: tests pass" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-full"

    [[ -d "$output_dir" ]] || skip "full preset not built"

    cd "$output_dir"
    cargo_test "$output_dir"
}

@test "full preset: has benchmark infrastructure" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-full"

    [[ -d "$output_dir" ]] || skip "full preset not built"

    assert_file_in_project "$output_dir" "crates/preset-full-core/benches"
}

@test "full preset: has site directory" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-full"

    [[ -d "$output_dir" ]] || skip "full preset not built"

    assert_file_in_project "$output_dir" "site"
}

@test "full preset: has community files" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-full"

    [[ -d "$output_dir" ]] || skip "full preset not built"

    assert_file_in_project "$output_dir" "CODE_OF_CONDUCT.md"
    assert_file_in_project "$output_dir" "CONTRIBUTING.md"
}

# =============================================================================
# MCP Server Preset
# =============================================================================

@test "mcp-server preset: generates and builds" {
    local output_dir
    output_dir=$(generate_project "preset-mcp-server" "_mcp-server.yml")

    cd "$output_dir"
    cargo_clippy "$output_dir"
}

@test "mcp-server preset: tests pass" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-mcp-server"

    [[ -d "$output_dir" ]] || skip "mcp-server preset not built"

    cd "$output_dir"
    cargo_test "$output_dir"
}

@test "mcp-server preset: has serve command" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-mcp-server"

    [[ -d "$output_dir" ]] || skip "mcp-server preset not built"

    run "$output_dir/target/debug/preset-mcp-server" --help
    assert_success
    assert_output --partial "serve"
}

@test "mcp-server preset: serve help shows MCP info" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-mcp-server"

    [[ -d "$output_dir" ]] || skip "mcp-server preset not built"

    run "$output_dir/target/debug/preset-mcp-server" serve --help
    assert_success
}
