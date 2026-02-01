# test/test_helper.bash
# Common setup for all bats tests

# Project root (parent of test/)
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
export PROJECT_ROOT

# Template test output directory
export TEST_OUTPUT_DIR="${PROJECT_ROOT}/target/template-tests"

# Load bats libraries
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/bats-file/load'

# =============================================================================
# Preset Discovery (reads from YAML source of truth)
# =============================================================================

# Get list of all preset names (including variants with underscore prefix)
# Usage: get_all_preset_names
get_all_preset_names() {
    local presets_dir="${PROJECT_ROOT}/scripts/presets"
    for f in "$presets_dir"/*.yml; do
        basename "$f" .yml
    done
}

# Get list of primary preset names (excludes underscore-prefixed variants)
# Usage: get_primary_preset_names
get_primary_preset_names() {
    local presets_dir="${PROJECT_ROOT}/scripts/presets"
    for f in "$presets_dir"/*.yml; do
        local name
        name=$(basename "$f" .yml)
        [[ "$name" != _* ]] && echo "$name"
    done
}

# Get a value from a preset YAML file
# Usage: get_preset_value "minimal" "has_cli"
get_preset_value() {
    local preset="$1"
    local key="$2"
    local presets_dir="${PROJECT_ROOT}/scripts/presets"
    local preset_file="${presets_dir}/${preset}.yml"

    # Handle underscore-prefixed variants
    if [[ ! -f "$preset_file" ]]; then
        preset_file="${presets_dir}/_${preset}.yml"
    fi

    yq -r ".${key} // empty" "$preset_file"
}

# Check if preset has a feature enabled
# Usage: preset_has_feature "full" "has_benchmarks" && echo "yes"
preset_has_feature() {
    local preset="$1"
    local key="$2"
    [[ "$(get_preset_value "$preset" "$key")" == "true" ]]
}

# =============================================================================
# Helper Functions
# =============================================================================

# Generate a project from template with given data file
# Usage: generate_project "test-name" "data-file.yml"
generate_project() {
    local test_name="$1"
    local data_file="$2"
    local output_dir="${TEST_OUTPUT_DIR}/${test_name}"

    rm -rf "$output_dir"
    mkdir -p "$output_dir"

    # Test defaults for required fields without copier.yaml defaults
    local data_args=(
        --data "project_name=${test_name}"
        --data "owner=test-owner"
        --data "copyright_name=Test Copyright"
        --data "conduct_email=conduct@test.org"
    )

    if [[ -n "$data_file" ]]; then
        copier copy --trust --defaults \
            --data-file "${PROJECT_ROOT}/scripts/presets/${data_file}" \
            "${data_args[@]}" \
            "$PROJECT_ROOT" "$output_dir" >&2
    else
        copier copy --trust --defaults \
            "${data_args[@]}" \
            "$PROJECT_ROOT" "$output_dir" >&2
    fi

    # Return only the path
    printf '%s' "$output_dir"
}

# Generate a project with inline data overrides
# Usage: generate_project_with_data "test-name" "base-preset.yml" "key=value" "key2=value2"
generate_project_with_data() {
    local test_name="$1"
    local data_file="$2"
    shift 2
    local output_dir="${TEST_OUTPUT_DIR}/${test_name}"

    rm -rf "$output_dir"
    mkdir -p "$output_dir"

    # Build --data arguments (include test defaults for required fields)
    local data_args=(
        --data "project_name=${test_name}"
        --data "owner=test-owner"
        --data "copyright_name=Test Copyright"
        --data "conduct_email=conduct@test.org"
    )
    for arg in "$@"; do
        data_args+=(--data "$arg")
    done

    copier copy --trust --defaults \
        --data-file "${PROJECT_ROOT}/scripts/presets/${data_file}" \
        "${data_args[@]}" \
        "$PROJECT_ROOT" "$output_dir" >&2

    # Return only the path
    printf '%s' "$output_dir"
}

# Check if a path exists in generated project (file or directory)
# Usage: assert_file_in_project "$output_dir" "path/to/file"
assert_file_in_project() {
    local project_dir="$1"
    local file_path="$2"
    local full_path="${project_dir}/${file_path}"

    if [[ -d "$full_path" ]]; then
        assert_dir_exists "$full_path"
    else
        assert_file_exists "$full_path"
    fi
}

# Check if a path does NOT exist in generated project (file or directory)
# Usage: assert_no_file_in_project "$output_dir" "path/to/file"
assert_no_file_in_project() {
    local project_dir="$1"
    local file_path="$2"
    local full_path="${project_dir}/${file_path}"

    # Use test -e to check if path exists at all (file, dir, symlink, etc.)
    if [[ -e "$full_path" ]]; then
        fail "Expected '$file_path' to NOT exist, but it does: $full_path"
    fi
}

# Check if file contains a string
# Usage: assert_file_contains "$output_dir" "path/to/file" "expected content"
assert_file_contains() {
    local project_dir="$1"
    local file_path="$2"
    local expected="$3"
    local full_path="${project_dir}/${file_path}"

    assert_file_exists "$full_path"
    run grep -q "$expected" "$full_path"
    assert_success
}

# Check if file does NOT contain a string
# Usage: assert_file_not_contains "$output_dir" "path/to/file" "unexpected content"
assert_file_not_contains() {
    local project_dir="$1"
    local file_path="$2"
    local unexpected="$3"
    local full_path="${project_dir}/${file_path}"

    assert_file_exists "$full_path"
    run grep -q "$unexpected" "$full_path"
    assert_failure
}

# Run cargo check in generated project
# Usage: cargo_check "$output_dir"
cargo_check() {
    local project_dir="$1"
    cd "$project_dir"
    run cargo check --all-targets
    assert_success
}

# Run cargo clippy in generated project
# Usage: cargo_clippy "$output_dir"
cargo_clippy() {
    local project_dir="$1"
    cd "$project_dir"
    run cargo clippy --all-targets --all-features -- -D warnings
    assert_success
}

# Run cargo nextest in generated project
# Usage: cargo_test "$output_dir"
cargo_test() {
    local project_dir="$1"
    cd "$project_dir"
    run cargo nextest run
    assert_success
}

# =============================================================================
# Setup/Teardown
# =============================================================================

# Common setup - ensure output directory exists
common_setup() {
    mkdir -p "$TEST_OUTPUT_DIR"
}

# Per-test setup (can be overridden in test files)
setup() {
    common_setup
}
