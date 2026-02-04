#!/usr/bin/env bats
# test/progressive.bats
# Progressive enhancement tests - validate feature additions/removals via copier update
#
# These tests verify the real-world workflow of:
# - Starting minimal and progressively adding features
# - Starting full and progressively removing features
#
# SLOW: Each test builds multiple cargo projects (one per step)

load 'test_helper'

# =============================================================================
# Feature → nextest filter mapping
# =============================================================================
# Maps feature aliases to nextest filter expressions for targeted testing.
# Empty string means "run full test suite" (feature has no specific tests).
#
# Note: Using a function with case statement instead of associative array
# because bats transforms script before bash execution, causing issues with
# top-level declare -A.

get_feature_filter() {
    local feature="$1"
    case "$feature" in
        config)   echo "test(/config/)" ;;
        jsonl)    echo "test(/(env_filter|log_target)/)" ;;
        otel)     echo "test(/observability_config/)" ;;
        mcp)      echo "test(/server|get_info/)" ;;
        # These features have no specific tests, verify build only
        core|bench|releases|site) echo "" ;;
        *)        echo "" ;;
    esac
}

# =============================================================================
# Helper: Run tests for a feature (or full suite if no specific filter)
# =============================================================================
run_feature_tests() {
    local project_dir="$1"
    local feature="$2"
    local filter
    filter=$(get_feature_filter "$feature")

    if [[ -n "$filter" ]]; then
        echo "  Running targeted tests: $filter" >&3
        cargo_nextest_filter "$project_dir" "$filter"
    else
        echo "  Running full test suite" >&3
        cargo_test "$project_dir"
    fi
}

# =============================================================================
# Helper: Log progress step
# =============================================================================
log_step() {
    local step="$1"
    local total="$2"
    local action="$3"
    echo "Step $step/$total: $action" >&3
}

# =============================================================================
# Staircase UP: minimal → full-featured
# =============================================================================
# Start with minimal preset, progressively add features, test at each step.
#
# Feature order (designed for logical dependencies):
# 1. +core    — adds core library crate
# 2. +config  — adds configuration support
# 3. +jsonl   — adds JSONL structured logging
# 4. +otel    — adds OpenTelemetry (brings tokio)
# 5. +mcp     — adds MCP server (also uses tokio)
# 6. +bench   — adds benchmarks
# 7. +releases — adds git-cliff release automation
# 8. +site    — adds documentation site

@test "progressive UP: minimal to full-featured" {
    local output_dir
    local total_steps=8

    # Step 0: Generate minimal baseline
    echo "Generating minimal baseline..." >&3
    output_dir=$(generate_project "prog-up" "minimal.yml")
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 1: +core
    log_step 1 $total_steps "+core (adds core library crate)"
    copier_recopy "$output_dir" "+core"
    cargo_clippy "$output_dir"
    run_feature_tests "$output_dir" "core"

    # Step 2: +config
    log_step 2 $total_steps "+config (adds configuration support)"
    copier_recopy "$output_dir" "+config"
    cargo_clippy "$output_dir"
    run_feature_tests "$output_dir" "config"

    # Step 3: +jsonl
    log_step 3 $total_steps "+jsonl (adds JSONL structured logging)"
    copier_recopy "$output_dir" "+jsonl"
    cargo_clippy "$output_dir"
    run_feature_tests "$output_dir" "jsonl"

    # Step 4: +otel
    log_step 4 $total_steps "+otel (adds OpenTelemetry)"
    copier_recopy "$output_dir" "+otel"
    cargo_clippy "$output_dir"
    run_feature_tests "$output_dir" "otel"

    # Step 5: +mcp
    log_step 5 $total_steps "+mcp (adds MCP server)"
    copier_recopy "$output_dir" "+mcp"
    cargo_clippy "$output_dir"
    run_feature_tests "$output_dir" "mcp"

    # Step 6: +bench
    log_step 6 $total_steps "+bench (adds benchmarks)"
    copier_recopy "$output_dir" "+bench"
    cargo_clippy "$output_dir"
    run_feature_tests "$output_dir" "bench"

    # Step 7: +releases
    log_step 7 $total_steps "+releases (adds git-cliff)"
    copier_recopy "$output_dir" "+releases"
    cargo_clippy "$output_dir"
    run_feature_tests "$output_dir" "releases"

    # Step 8: +site
    log_step 8 $total_steps "+site (adds documentation site)"
    copier_recopy "$output_dir" "+site"
    cargo_clippy "$output_dir"
    run_feature_tests "$output_dir" "site"

    # Final verification: full test suite
    echo "Final verification: running full test suite..." >&3
    cargo_test "$output_dir"
}

# =============================================================================
# Staircase DOWN: full → minimal
# =============================================================================
# Start with full preset, progressively remove features, test at each step.
#
# Feature removal order (reverse of UP):
# 1. -site
# 2. -releases
# 3. -bench
# 4. -mcp
# 5. -otel
# 6. -jsonl
# 7. -config
# 8. -core

@test "progressive DOWN: full to minimal" {
    local output_dir
    local total_steps=8

    # Step 0: Generate full baseline
    echo "Generating full baseline..." >&3
    output_dir=$(generate_project "prog-down" "full.yml")
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 1: -site
    log_step 1 $total_steps "-site (removes documentation site)"
    copier_recopy "$output_dir" "-site"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 2: -releases
    log_step 2 $total_steps "-releases (removes git-cliff)"
    copier_recopy "$output_dir" "-releases"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 3: -bench
    log_step 3 $total_steps "-bench (removes benchmarks)"
    copier_recopy "$output_dir" "-bench"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 4: -mcp (full preset doesn't have MCP enabled by default, but test anyway)
    log_step 4 $total_steps "-mcp (removes MCP server, if present)"
    copier_recopy "$output_dir" "-mcp"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 5: -otel
    log_step 5 $total_steps "-otel (removes OpenTelemetry)"
    copier_recopy "$output_dir" "-otel"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 6: -jsonl
    log_step 6 $total_steps "-jsonl (removes JSONL structured logging)"
    copier_recopy "$output_dir" "-jsonl"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 7: -config
    log_step 7 $total_steps "-config (removes configuration support)"
    copier_recopy "$output_dir" "-config"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 8: -core
    log_step 8 $total_steps "-core (removes core library crate)"
    copier_recopy "$output_dir" "-core"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Final verification
    echo "Final verification: running full test suite..." >&3
    cargo_test "$output_dir"
}

# =============================================================================
# Variant: full+otel → stripped
# =============================================================================
# Start with full preset plus OTEL enabled, strip down to minimal.
# Tests the scenario of inheriting a full-featured project and simplifying it.

@test "progressive DOWN: full+otel to stripped" {
    local output_dir
    local total_steps=9

    # Step 0: Generate full+otel baseline
    echo "Generating full+otel baseline..." >&3
    output_dir=$(generate_project_with_data "prog-full-otel" "full.yml" \
        "has_opentelemetry=true")
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 1: -site
    log_step 1 $total_steps "-site"
    copier_recopy "$output_dir" "-site"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 2: -releases
    log_step 2 $total_steps "-releases"
    copier_recopy "$output_dir" "-releases"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 3: -bench
    log_step 3 $total_steps "-bench"
    copier_recopy "$output_dir" "-bench"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 4: -mcp
    log_step 4 $total_steps "-mcp"
    copier_recopy "$output_dir" "-mcp"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 5: -otel (this is the key difference from "prog-down")
    log_step 5 $total_steps "-otel (key: removing OTEL from full+otel)"
    copier_recopy "$output_dir" "-otel"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 6: -jsonl
    log_step 6 $total_steps "-jsonl"
    copier_recopy "$output_dir" "-jsonl"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 7: -config
    log_step 7 $total_steps "-config"
    copier_recopy "$output_dir" "-config"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 8: -core
    log_step 8 $total_steps "-core"
    copier_recopy "$output_dir" "-core"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Step 9: -community (full preset has this enabled)
    log_step 9 $total_steps "-community"
    copier_recopy "$output_dir" "-community"
    cargo_clippy "$output_dir"
    cargo_test "$output_dir"

    # Final verification
    echo "Final verification: running full test suite..." >&3
    cargo_test "$output_dir"
}
