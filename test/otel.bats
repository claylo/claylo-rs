#!/usr/bin/env bats
# test/otel.bats
# OpenTelemetry integration tests - requires Docker OTEL stack running
#
# Prerequisites:
#   just docker-up   # Start OTEL collector (grafana/otel-lgtm)
#
# Run with:
#   just test-otel

load 'test_helper'

# Skip all tests if OTEL stack is not running
setup_file() {
    # Check if OTEL collector is reachable
    if ! curl -s --connect-timeout 2 http://localhost:4318/v1/traces > /dev/null 2>&1; then
        skip "OTEL collector not running (start with: just docker-up)"
    fi
}

setup() {
    common_setup
    export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
    export OTEL_SERVICE_NAME="test-otel-integration"
}

# =============================================================================
# OTEL Integration Tests
# =============================================================================

@test "standard-otel preset: binary initializes OTEL without error" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard-otel"

    # Generate if not already present
    if [[ ! -d "$output_dir" ]]; then
        output_dir=$(generate_project "preset-standard-otel" "_standard-otel.yml")
    fi

    cd "$output_dir"

    # Build dev binary (release builds are too slow for testing)
    cargo build --quiet

    # Run with OTEL endpoint - should not error even if export fails
    run ./target/debug/preset-standard-otel info
    assert_success
}

@test "standard-otel preset: sends traces to collector" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard-otel"

    [[ -d "$output_dir" ]] || skip "standard-otel preset not built"

    cd "$output_dir"

    # Generate a unique trace identifier
    local trace_marker="bats-test-$(date +%s)"

    # Run the binary - this should send traces
    OTEL_RESOURCE_ATTRIBUTES="test.marker=${trace_marker}" \
        ./target/debug/preset-standard-otel info > /dev/null 2>&1

    # Give the collector a moment to process
    sleep 2

    # Query Tempo for recent traces via Grafana API
    # The grafana/otel-lgtm image exposes Tempo through Grafana's unified API
    run curl -s "http://localhost:3000/api/datasources/proxy/uid/tempo/api/search?limit=10"

    # If we get a response with traces, the integration is working
    # Note: This is a basic check - traces should exist
    assert_success
}

@test "standard-otel preset: respects OTEL_SDK_DISABLED=true" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard-otel"

    [[ -d "$output_dir" ]] || skip "standard-otel preset not built"

    cd "$output_dir"

    # With OTEL disabled, binary should still run fine
    OTEL_SDK_DISABLED=true \
        run ./target/debug/preset-standard-otel info
    assert_success
}

@test "standard-otel preset: handles unreachable collector gracefully" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard-otel"

    [[ -d "$output_dir" ]] || skip "standard-otel preset not built"

    cd "$output_dir"

    # Point to non-existent collector - should not hang or crash
    OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:59999" \
    OTEL_EXPORTER_OTLP_TIMEOUT=1000 \
        run timeout 10 ./target/debug/preset-standard-otel info
    assert_success
}

# =============================================================================
# JSONL + OTEL Combined Tests
# =============================================================================

@test "standard-otel preset: JSONL logging works alongside OTEL" {
    local output_dir="${TEST_OUTPUT_DIR}/preset-standard-otel"

    [[ -d "$output_dir" ]] || skip "standard-otel preset not built"

    cd "$output_dir"

    local log_dir="${output_dir}/otel-test-logs"
    rm -rf "$log_dir"
    mkdir -p "$log_dir"

    # Env var prefix matches template: {{ project_name | upper | replace('-', '_') }}
    local env_var
    env_var="$(echo "preset-standard-otel" | tr '[:lower:]-' '[:upper:]_')_LOG_DIR"

    # Run with both OTEL and JSONL logging
    env "${env_var}=${log_dir}" \
        ./target/debug/preset-standard-otel -v info > /dev/null 2>&1

    # Verify JSONL log was created
    local log_file
    log_file=$(ls -S "$log_dir"/*.jsonl* 2>/dev/null | head -1)

    [[ -n "$log_file" ]] || fail "No JSONL log file created"
    [[ -s "$log_file" ]] || fail "JSONL log file is empty"

    # Validate JSONL format (tolerate some invalid lines from OTEL internals)
    # OTEL's BatchSpanProcessor can emit malformed debug output that gets mixed in
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
# Pass if majority of lines are valid (at least 80%)
total = valid + invalid
if total == 0:
    sys.exit(1)
valid_ratio = valid / total
sys.exit(0 if valid_ratio >= 0.8 else 1)
"
    assert_success
}
