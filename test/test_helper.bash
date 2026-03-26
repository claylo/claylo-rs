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

    # Initialize git repo so copier update (three-way merge) can work
    git -C "$output_dir" init --quiet >&2
    git -C "$output_dir" add -A >&2
    git -C "$output_dir" commit --quiet -m "initial generation" >&2

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

    # Initialize git repo so copier update (three-way merge) can work
    git -C "$output_dir" init --quiet >&2
    git -C "$output_dir" add -A >&2
    git -C "$output_dir" commit --quiet -m "initial generation" >&2

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
# Exit code 4 = no tests to run (e.g., library preset with no test files yet)
cargo_test() {
    local project_dir="$1"
    cd "$project_dir"
    run cargo nextest run --status-level=fail
    if [[ "$status" -ne 0 && "$status" -ne 4 ]]; then
        assert_success  # will fail with the actual error
    fi
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

# Update a generated project using the claylo-rs wrapper
# Usage: wrapper_update project_dir "+feature" "-feature" ...
#
# Uses the actual wrapper script (bin/claylo-rs update --local) so tests
# exercise the real user workflow. Requires the generated project to have
# git history (generate_project handles this).
wrapper_update() {
    local project_dir="$1"
    shift

    # Build feature flag string (e.g., "+core+config-bench")
    local features=""
    for arg in "$@"; do
        features="${features}${arg}"
    done

    # Commit any pending changes so copier update has a clean working tree
    # Use git status --porcelain to catch both tracked changes AND untracked files
    # (e.g., Cargo.lock created by cargo build)
    if [[ -n "$(git -C "$project_dir" status --porcelain 2>/dev/null)" ]]; then
        git -C "$project_dir" add -A >&2
        git -C "$project_dir" commit --quiet -m "pre-update snapshot" >&2
    fi

    # Run the wrapper — same code path as real users
    local -a cmd=("${PROJECT_ROOT}/bin/claylo-rs" update --local -y)
    [[ -n "$features" ]] && cmd+=("$features")
    cmd+=("$project_dir")

    "${cmd[@]}" >&2
    local exit_code=$?

    # Commit the update so the next update has a clean base
    if [[ $exit_code -eq 0 ]]; then
        git -C "$project_dir" add -A >&2
        git -C "$project_dir" commit --quiet -m "updated: $features" --allow-empty >&2
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
