#!/usr/bin/env bats
# test/wrapper.bats
# Tests for bin/claylo-rs copier wrapper

load 'test_helper'

WRAPPER="${PROJECT_ROOT}/bin/claylo-rs"

# Create a mock copier that records the command it receives
setup() {
    common_setup
    export MOCK_DIR="${TEST_OUTPUT_DIR}/wrapper-mock"
    mkdir -p "$MOCK_DIR"

    # Mock copier: record args to a file instead of running copier
    cat > "${MOCK_DIR}/copier" <<'MOCK'
#!/usr/bin/env bash
echo "$@" > "${MOCK_DIR}/copier-args"
MOCK
    chmod +x "${MOCK_DIR}/copier"

    # Change to mock dir to prevent finding user's personal defaults file
    # (find_defaults_file walks from PWD upward)
    cd "$MOCK_DIR"
}

# =============================================================================
# Help & Usage
# =============================================================================

@test "wrapper: --help shows usage" {
    run "$WRAPPER" --help
    assert_success
    assert_line --partial "Usage: claylo-rs"
    assert_line --partial "new <dest>"
    assert_line --partial "update [dest]"
    assert_line --partial "+feature-flags"
}

@test "wrapper: no args shows usage and exits 1" {
    run "$WRAPPER"
    assert_failure
    assert_line --partial "Usage: claylo-rs"
}

@test "wrapper: help subcommand shows usage" {
    run "$WRAPPER" help
    assert_success
    assert_line --partial "Usage: claylo-rs"
}

# =============================================================================
# Error Handling
# =============================================================================

@test "wrapper: unknown command exits with error" {
    run "$WRAPPER" destroy
    assert_failure
    assert_line --partial "unknown command 'destroy'"
}

@test "wrapper: new without dest exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new
    assert_failure
    assert_line --partial "destination path required"
}

@test "wrapper: unknown feature alias exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo +bogus
    assert_failure
    assert_line --partial "unknown feature 'bogus'"
    assert_line --partial "Valid features:"
}

@test "wrapper: invalid preset exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --preset mega
    assert_failure
    assert_line --partial "invalid preset 'mega'"
}

@test "wrapper: invalid lint level exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --lint super
    assert_failure
    assert_line --partial "invalid lint level 'super'"
}

@test "wrapper: invalid hook system exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --hook cargo
    assert_failure
    assert_line --partial "invalid hook system 'cargo'"
}

@test "wrapper: empty feature name exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo +-
    assert_failure
}

@test "wrapper: --preset without value exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --preset
    assert_failure
    assert_line --partial "--preset requires a value"
}

@test "wrapper: --lint without value exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --lint
    assert_failure
    assert_line --partial "--lint requires a value"
}

@test "wrapper: --data without value exits with error" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --data
    assert_failure
    assert_line --partial "--data requires a key=value"
}

# =============================================================================
# Command Building — new
# =============================================================================

@test "wrapper: new builds correct copier copy command" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./my-app
    assert_success
    # Command is printed in multi-line format
    assert_output --partial "copier copy"
    assert_output --partial "project_name=my-app"
    assert_output --partial "preset=standard"
}

@test "wrapper: new derives project_name from dest basename" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new /some/deep/path/cool-cli
    assert_success
    assert_output --partial "--data project_name=cool-cli"
}

@test "wrapper: new with --preset passes preset" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --preset full
    assert_success
    assert_output --partial "--data preset=full"
}

@test "wrapper: new with --lint passes lint_level" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --lint strict
    assert_success
    assert_output --partial "--data lint_level=strict"
}

@test "wrapper: new with --hook passes hook_system" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --hook lefthook
    assert_success
    assert_output --partial "--data hook_system=lefthook"
}

@test "wrapper: new with --owner passes owner" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --owner myorg
    assert_success
    assert_output --partial "--data owner=myorg"
}

@test "wrapper: new with --copyright passes copyright_name" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --copyright 'Test Org'
    assert_success
    # Values with spaces get quoted in output
    assert_output --partial "copyright_name=Test Org"
}

@test "wrapper: new with --desc passes project_description" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --desc 'My cool project'
    assert_success
    # Values with spaces get quoted in output
    assert_output --partial "project_description=My cool project"
}

@test "wrapper: new with --dry-run adds --pretend" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --dry-run
    assert_success
    assert_output --partial "--pretend"
}

@test "wrapper: new with --data passes through to copier" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo --data edition=2021 --data msrv=1.80.0
    assert_success
    assert_output --partial "--data edition=2021"
    assert_output --partial "--data msrv=1.80.0"
}

# =============================================================================
# Command Building — update
# =============================================================================

@test "wrapper: update builds correct copier update command" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" update ./my-app
    assert_success
    # Command is printed in multi-line format
    assert_output --partial "copier update"
    # update should NOT include --defaults
    refute_output --partial "--defaults"
}

@test "wrapper: update defaults dest to dot" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" update
    assert_success
    # Command should include "." as destination
    assert_output --partial "copier update"
    # Destination "." appears on its own line (with leading whitespace in multi-line format)
    assert_line --partial "."
}

@test "wrapper: update does not pass preset by default" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" update ./foo
    assert_success
    refute_output --partial "--data preset="
}

@test "wrapper: update passes preset only when explicitly set" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" update ./foo --preset full
    assert_success
    assert_output --partial "--data preset=full"
}

# =============================================================================
# Feature Flag Parsing
# =============================================================================

@test "wrapper: +otel enables has_opentelemetry" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo +otel
    assert_success
    assert_output --partial "--data has_opentelemetry=true"
}

@test "wrapper: -site disables has_site" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo -site
    assert_success
    assert_output --partial "--data has_site=false"
}

@test "wrapper: compound feature string +otel-site+bench" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo +otel-site+bench
    assert_success
    assert_output --partial "--data has_opentelemetry=true"
    assert_output --partial "--data has_site=false"
    assert_output --partial "--data has_benchmarks=true"
}

@test "wrapper: multiple separate feature args" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo +otel -site +bench
    assert_success
    assert_output --partial "--data has_opentelemetry=true"
    assert_output --partial "--data has_site=false"
    assert_output --partial "--data has_benchmarks=true"
}

@test "wrapper: all feature aliases resolve correctly" {
    # Spot-check a selection of aliases across categories
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new ./foo \
        +core+config+jsonl+claude_skills+env+issues+md_strict+skill_git
    assert_success
    assert_output --partial "--data has_core_library=true"
    assert_output --partial "--data has_config=true"
    assert_output --partial "--data has_jsonl_logging=true"
    assert_output --partial "--data has_claude_skills=true"
    assert_output --partial "--data has_env_files=true"
    assert_output --partial "--data has_issue_templates=true"
    assert_output --partial "--data has_md_strict=true"
    assert_output --partial "--data has_skill_using_git=true"
}

@test "wrapper: features work with update command" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" update ./foo +otel-community
    assert_success
    assert_output --partial "--data has_opentelemetry=true"
    assert_output --partial "--data has_community_files=false"
}

# =============================================================================
# Argument Order Independence
# =============================================================================

@test "wrapper: flags can appear in any order" {
    PATH="${MOCK_DIR}:${PATH}" run "$WRAPPER" new +otel --preset full ./my-app --lint strict -site
    assert_success
    assert_output --partial "--data project_name=my-app"
    assert_output --partial "--data preset=full"
    assert_output --partial "--data lint_level=strict"
    assert_output --partial "--data has_opentelemetry=true"
    assert_output --partial "--data has_site=false"
}
