#!/usr/bin/env bats
# test/add_crate.bats
# Functional tests for scripts/add-crate (requires cargo — slower)

load 'test_helper'

# =============================================================================
# Library Crate
# =============================================================================

@test "add-crate creates a library crate in claylo-rs project" {
    local output_dir
    output_dir=$(generate_project_with_data "add-crate-lib" "standard.yml")

    # Run the script non-interactively
    cd "$output_dir"
    run ./scripts/add-crate lib my-utils -d "Test utilities"
    assert_success

    # Verify files created
    [[ -f "crates/my-utils/Cargo.toml" ]]
    [[ -f "crates/my-utils/src/lib.rs" ]]

    # Verify Cargo.toml has workspace inheritance (claylo-rs convention)
    grep -q 'name = "my-utils"' "crates/my-utils/Cargo.toml"
    grep -q 'version.workspace = true' "crates/my-utils/Cargo.toml"
    grep -q 'edition.workspace = true' "crates/my-utils/Cargo.toml"
    grep -q 'publish = false' "crates/my-utils/Cargo.toml"
    grep -q 'thiserror' "crates/my-utils/Cargo.toml"

    # Verify workspace lints inheritance
    grep -q 'workspace = true' "crates/my-utils/Cargo.toml"

    # Verify lib.rs has doc comment
    grep -q '//! my-utils' "crates/my-utils/src/lib.rs"
}

# =============================================================================
# Binary Crate
# =============================================================================

@test "add-crate creates a binary crate with anyhow pattern" {
    local output_dir
    output_dir=$(generate_project_with_data "add-crate-bin" "standard.yml")

    cd "$output_dir"
    run ./scripts/add-crate bin my-daemon -d "Background daemon"
    assert_success

    # Verify files
    [[ -f "crates/my-daemon/Cargo.toml" ]]
    [[ -f "crates/my-daemon/src/main.rs" ]]

    # Verify conventional deps
    grep -q 'anyhow' "crates/my-daemon/Cargo.toml"
    grep -q 'clap' "crates/my-daemon/Cargo.toml"

    # Verify main.rs uses run() -> Result pattern
    grep -q 'fn run()' "crates/my-daemon/src/main.rs"
    grep -q 'ExitCode' "crates/my-daemon/src/main.rs"
}

# =============================================================================
# Internal / Proc-Macro Crate
# =============================================================================

@test "add-crate creates a proc-macro crate with --derive" {
    local output_dir
    output_dir=$(generate_project_with_data "add-crate-derive" "standard.yml")

    cd "$output_dir"
    run ./scripts/add-crate internal my-derive --derive -d "Derive macros"
    assert_success

    # Verify proc-macro flag
    grep -q 'proc-macro = true' "crates/my-derive/Cargo.toml"

    # Verify it's a lib crate (not bin)
    [[ -f "crates/my-derive/src/lib.rs" ]]
    [[ ! -f "crates/my-derive/src/main.rs" ]]
}

# =============================================================================
# Validation
# =============================================================================

@test "add-crate rejects duplicate crate names" {
    local output_dir
    output_dir=$(generate_project_with_data "add-crate-dup" "standard.yml")

    cd "$output_dir"
    # The project already has a crate named after the project
    run ./scripts/add-crate lib add-crate-dup -d "Duplicate"
    assert_failure
}

@test "add-crate rejects --derive with non-internal type" {
    local output_dir
    output_dir=$(generate_project_with_data "add-crate-derive-lib" "standard.yml")

    cd "$output_dir"
    run ./scripts/add-crate lib my-macros --derive -d "Bad combo"
    assert_failure
}

@test "add-crate rejects invalid crate names" {
    local output_dir
    output_dir=$(generate_project_with_data "add-crate-invalid" "standard.yml")

    cd "$output_dir"

    # Starts with uppercase
    run ./scripts/add-crate lib MyUtils -d "Bad name"
    assert_failure

    # Rust keyword
    run ./scripts/add-crate lib self -d "Bad name"
    assert_failure

    # Double hyphen
    run ./scripts/add-crate lib my--utils -d "Bad name"
    assert_failure
}

# =============================================================================
# Compilation
# =============================================================================

@test "add-crate lib compiles in workspace" {
    local output_dir
    output_dir=$(generate_project_with_data "add-crate-compile-lib" "standard.yml")

    cd "$output_dir"
    ./scripts/add-crate lib my-utils -d "Test utilities"

    # Verify the whole workspace compiles
    run cargo check --quiet --workspace
    assert_success
}

@test "add-crate bin compiles in workspace" {
    local output_dir
    output_dir=$(generate_project_with_data "add-crate-compile-bin" "standard.yml")

    cd "$output_dir"
    ./scripts/add-crate bin my-daemon -d "Background daemon"

    run cargo check --quiet --workspace
    assert_success
}
