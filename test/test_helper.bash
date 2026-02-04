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

# Environment variables for faster template test builds
# (fresh builds each time = no incremental benefit, just overhead)
export CARGO_PROFILE_DEV_INCREMENTAL=false
export CARGO_PROFILE_TEST_INCREMENTAL=false

# Use lld for faster linking on macOS (if available)
# Cargo doesn't auto-detect installed linkers, so we configure explicitly
if [[ "$OSTYPE" == "darwin"* ]] && [[ -x "/usr/local/bin/ld64.lld" ]]; then
    export CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER=clang
    export CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS="-C link-arg=-fuse-ld=/usr/local/bin/ld64.lld"
    export CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER=clang
    export CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS="-C link-arg=-fuse-ld=/usr/local/bin/ld64.lld"
fi

# Run cargo check in generated project
# Usage: cargo_check "$output_dir"
cargo_check() {
    local project_dir="$1"
    cd "$project_dir"
    run cargo check --quiet --all-targets
    assert_success
}

# Run cargo clippy in generated project (also builds binaries for subsequent tests)
# Usage: cargo_clippy "$output_dir"
cargo_clippy() {
    local project_dir="$1"
    cd "$project_dir"
    # Build first (clippy alone doesn't produce binaries)
    run cargo build --quiet
    assert_success
    # Then lint
    run cargo clippy --quiet --all-targets --all-features -- -D warnings
    assert_success
}

# Run cargo nextest in generated project
# Usage: cargo_test "$output_dir"
cargo_test() {
    local project_dir="$1"
    cd "$project_dir"
    run cargo nextest run --status-level=fail
    assert_success
}

# Run cargo nextest with a filter expression
# Usage: cargo_nextest_filter "$output_dir" "test(/pattern/)"
cargo_nextest_filter() {
    local project_dir="$1"
    local filter="$2"
    cd "$project_dir"
    run cargo nextest run --status-level=fail -E "$filter"
    assert_success
}

# Clean up orphaned files after feature removal
# Copier doesn't delete files when features are disabled, so we do it manually.
# Usage: cleanup_orphaned_files project_dir
cleanup_orphaned_files() {
    local project_dir="$1"
    local answers_file="${project_dir}/.repo.yml"
    local project_name

    project_name=$(yq -r '.project_name' "$answers_file")

    # Helper to check if a feature is disabled (false or missing)
    is_disabled() {
        local value
        value=$(yq -r ".$1 // false" "$answers_file")
        [[ "$value" == "false" ]]
    }

    # Cleanup for has_benchmarks=false
    if is_disabled "has_benchmarks"; then
        rm -rf "${project_dir}/crates/${project_name}-core/benches" 2>/dev/null
        rm -rf "${project_dir}/bench-reports" 2>/dev/null
        rm -f "${project_dir}/scripts/bench-cli.sh" 2>/dev/null
        rm -f "${project_dir}/docs/benchmarks-howto.md" 2>/dev/null
    fi

    # Cleanup for has_xtask=false
    if is_disabled "has_xtask"; then
        rm -rf "${project_dir}/xtask" 2>/dev/null
    fi

    # Cleanup for has_site=false
    if is_disabled "has_site"; then
        rm -rf "${project_dir}/site" 2>/dev/null
    fi

    # Cleanup for has_mcp_server=false
    if is_disabled "has_mcp_server"; then
        rm -f "${project_dir}/crates/${project_name}/src/commands/serve.rs" 2>/dev/null
        rm -f "${project_dir}/crates/${project_name}/src/server.rs" 2>/dev/null
    fi

    # Cleanup for has_core_library=false
    if is_disabled "has_core_library"; then
        rm -rf "${project_dir}/crates/${project_name}-core" 2>/dev/null
    fi

    # Cleanup for has_config=false
    if is_disabled "has_config"; then
        rm -f "${project_dir}/crates/${project_name}/src/config.rs" 2>/dev/null
        rm -f "${project_dir}/crates/${project_name}-core/src/config.rs" 2>/dev/null
        rm -rf "${project_dir}/config" 2>/dev/null
        rm -f "${project_dir}/crates/${project_name}/tests/config_integration.rs" 2>/dev/null
    fi

    # Cleanup for has_releases=false
    if is_disabled "has_releases"; then
        rm -f "${project_dir}/cliff.toml" 2>/dev/null
        rm -f "${project_dir}/docs/releases.md" 2>/dev/null
    fi

    # Cleanup for has_community_files=false
    if is_disabled "has_community_files"; then
        rm -f "${project_dir}/CODE_OF_CONDUCT.md" 2>/dev/null
        rm -f "${project_dir}/CONTRIBUTING.md" 2>/dev/null
    fi

    # Cleanup for observability (both jsonl and otel must be false)
    if is_disabled "has_jsonl_logging" && is_disabled "has_opentelemetry"; then
        rm -f "${project_dir}/crates/${project_name}/src/observability.rs" 2>/dev/null
    fi

    return 0
}

# Run copier recopy on an existing project with feature flags
# Usage: copier_recopy project_dir "+feature" "-feature" ...
#
# Uses copier recopy instead of update because recopy doesn't need
# _commit history (works with local template development).
#
# To properly merge feature flag changes with existing answers, we:
# 1. Copy the existing .repo.yml to a temp file
# 2. Use yq to update the specific values
# 3. Run recopy with --data-file pointing to the merged answers
# 4. Clean up orphaned files that copier doesn't delete
copier_recopy() {
    local project_dir="$1"
    shift

    local answers_file="${project_dir}/.repo.yml"
    local temp_answers
    temp_answers=$(mktemp)

    # Copy existing answers to temp file
    cp "$answers_file" "$temp_answers"

    # Apply feature flag changes using yq
    for arg in "$@"; do
        case "$arg" in
            +core)    yq -i '.has_core_library = true' "$temp_answers" ;;
            -core)    yq -i '.has_core_library = false' "$temp_answers" ;;
            +config)  yq -i '.has_config = true' "$temp_answers" ;;
            -config)  yq -i '.has_config = false' "$temp_answers" ;;
            +jsonl)   yq -i '.has_jsonl_logging = true' "$temp_answers" ;;
            -jsonl)   yq -i '.has_jsonl_logging = false' "$temp_answers" ;;
            +otel)    yq -i '.has_opentelemetry = true' "$temp_answers" ;;
            -otel)    yq -i '.has_opentelemetry = false' "$temp_answers" ;;
            +mcp)     yq -i '.has_mcp_server = true' "$temp_answers" ;;
            -mcp)     yq -i '.has_mcp_server = false' "$temp_answers" ;;
            +bench)   yq -i '.has_benchmarks = true' "$temp_answers" ;;
            -bench)   yq -i '.has_benchmarks = false' "$temp_answers" ;;
            +releases) yq -i '.has_releases = true' "$temp_answers" ;;
            -releases) yq -i '.has_releases = false' "$temp_answers" ;;
            +site)    yq -i '.has_site = true' "$temp_answers" ;;
            -site)    yq -i '.has_site = false' "$temp_answers" ;;
            +community) yq -i '.has_community_files = true' "$temp_answers" ;;
            -community) yq -i '.has_community_files = false' "$temp_answers" ;;
            *)
                echo "Unknown feature flag: $arg" >&2
                rm -f "$temp_answers"
                return 1
                ;;
        esac
    done

    copier recopy --force \
        --skip-answered \
        --answers-file .repo.yml \
        --data-file "$temp_answers" \
        "$project_dir" >&2
    local exit_code=$?

    rm -f "$temp_answers"

    # Clean up orphaned files after recopy
    if [[ $exit_code -eq 0 ]]; then
        cleanup_orphaned_files "$project_dir"
    fi

    return $exit_code
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
