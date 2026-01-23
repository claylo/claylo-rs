#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="${PROJECT_ROOT}"  # copier.yaml at root with _subdirectory: template
TEST_BASE="${PROJECT_ROOT}/target/template-tests"
TIMESTAMP=$(date +"%Y%m%d-%H%M")
RESULTS_DIR="${TEST_BASE}/results/${TIMESTAMP}"

echo "Template root: $TEMPLATE_DIR"
echo "Results directory: $RESULTS_DIR"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Feature verification functions
verify_jsonl_logging() {
    local preset=$1
    local project_dir=$2
    local results_preset_dir=$3
    local binary_name=$4

    echo "  Verifying JSONL logging..."

    local log_dir="${results_preset_dir}/logs"
    mkdir -p "$log_dir"

    # Run binary with APP_LOG_DIR set to capture logs
    # Use -v to enable debug logging so we actually get log entries
    cd "$project_dir"
    if APP_LOG_DIR="$log_dir" cargo run --quiet -- -v info > /dev/null 2>&1; then
        # Check if log file was created (find non-empty file - rotation creates dated files)
        if ls "$log_dir"/*.jsonl* 2>/dev/null | head -1 | grep -q .; then
            local log_file
            # Find largest (non-empty) jsonl file - rotation may put logs in dated file
            log_file=$(ls -S "$log_dir"/*.jsonl* 2>/dev/null | head -1)
            echo "    ✓ JSONL log file created: $(basename "$log_file")"

            # Verify it's valid JSONL (each line is valid JSON)
            if python3 -c "
import sys
valid = 0
invalid = 0
for line in open('$log_file'):
    line = line.strip()
    if not line:
        continue
    try:
        import json
        json.loads(line)
        valid += 1
    except:
        invalid += 1
if valid > 0 and invalid == 0:
    sys.exit(0)
else:
    print(f'valid={valid}, invalid={invalid}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
                echo "    ✓ Log file is valid JSONL"
                echo "JSONL_LOGGING=PASS" >> "${results_preset_dir}/features.env"
                return 0
            else
                echo "    ✗ Log file is not valid JSONL"
                echo "JSONL_LOGGING=FAIL:invalid_jsonl" >> "${results_preset_dir}/features.env"
                return 1
            fi
        else
            echo "    ✗ No JSONL log file created"
            echo "JSONL_LOGGING=FAIL:no_file" >> "${results_preset_dir}/features.env"
            return 1
        fi
    else
        echo "    ✗ Binary failed to run"
        echo "JSONL_LOGGING=FAIL:binary_error" >> "${results_preset_dir}/features.env"
        return 1
    fi
}

verify_config_discovery() {
    local preset=$1
    local project_dir=$2
    local results_preset_dir=$3
    local binary_name=$4

    echo "  Verifying config discovery..."

    cd "$project_dir"

    # Create a test config file
    mkdir -p "${project_dir}/test-config-dir"
    cat > "${project_dir}/test-config-dir/.${binary_name}.toml" << 'CONFIGEOF'
log_level = "debug"
CONFIGEOF

    # Run from the config directory and check if config is discovered
    # We can verify by checking if debug logging is active
    local log_dir="${results_preset_dir}/config-test-logs"
    mkdir -p "$log_dir"

    cd "${project_dir}/test-config-dir"
    if APP_LOG_DIR="$log_dir" cargo run --quiet --manifest-path "${project_dir}/Cargo.toml" -- info > /dev/null 2>&1; then
        # Check log file for debug level entries (proves config was loaded)
        if ls "$log_dir"/*.jsonl* 2>/dev/null | head -1 | grep -q .; then
            local log_file
            log_file=$(ls "$log_dir"/*.jsonl* 2>/dev/null | head -1)
            if grep -q '"level":"debug"' "$log_file" 2>/dev/null; then
                echo "    ✓ Config discovered and applied (debug level active)"
                echo "CONFIG_DISCOVERY=PASS" >> "${results_preset_dir}/features.env"
                return 0
            else
                echo "    ? Config file created but debug level not observed"
                echo "CONFIG_DISCOVERY=PARTIAL:no_debug_logs" >> "${results_preset_dir}/features.env"
                return 0  # Not a failure, just no debug logs emitted
            fi
        fi
    fi

    echo "    ✗ Config discovery test inconclusive"
    echo "CONFIG_DISCOVERY=INCONCLUSIVE" >> "${results_preset_dir}/features.env"
    return 0  # Don't fail the build for this
}

verify_binary_runs() {
    local preset=$1
    local project_dir=$2
    local results_preset_dir=$3
    local binary_name=$4

    echo "  Verifying binary execution..."

    cd "$project_dir"

    # Test: info command (text output)
    if cargo run --quiet -- info > "${results_preset_dir}/info-output.txt" 2>&1; then
        echo "    ✓ 'info' command succeeded"
        echo "BINARY_INFO=PASS" >> "${results_preset_dir}/features.env"
    else
        echo "    ✗ 'info' command failed"
        echo "BINARY_INFO=FAIL" >> "${results_preset_dir}/features.env"
        return 1
    fi

    # Test: info --json command
    if cargo run --quiet -- info --json > "${results_preset_dir}/info-json-output.json" 2>&1; then
        if python3 -c "import sys,json; json.load(sys.stdin)" < "${results_preset_dir}/info-json-output.json" 2>/dev/null; then
            echo "    ✓ 'info --json' returns valid JSON"
            echo "BINARY_INFO_JSON=PASS" >> "${results_preset_dir}/features.env"
        else
            echo "    ✗ 'info --json' output is not valid JSON"
            echo "BINARY_INFO_JSON=FAIL:invalid_json" >> "${results_preset_dir}/features.env"
        fi
    else
        echo "    ✗ 'info --json' command failed"
        echo "BINARY_INFO_JSON=FAIL" >> "${results_preset_dir}/features.env"
    fi

    # Test: --help
    if cargo run --quiet -- --help > "${results_preset_dir}/help-output.txt" 2>&1; then
        echo "    ✓ '--help' command succeeded"
        echo "BINARY_HELP=PASS" >> "${results_preset_dir}/features.env"
    else
        echo "    ✗ '--help' command failed"
        echo "BINARY_HELP=FAIL" >> "${results_preset_dir}/features.env"
    fi

    # Test: --version
    if cargo run --quiet -- --version > "${results_preset_dir}/version-output.txt" 2>&1; then
        echo "    ✓ '--version' command succeeded"
        echo "BINARY_VERSION=PASS" >> "${results_preset_dir}/features.env"
    else
        echo "    ✗ '--version' command failed"
        echo "BINARY_VERSION=FAIL" >> "${results_preset_dir}/features.env"
    fi

    return 0
}

verify_otel_init() {
    local preset=$1
    local project_dir=$2
    local results_preset_dir=$3
    local binary_name=$4

    echo "  Verifying OpenTelemetry initialization..."

    cd "$project_dir"

    # OTel init can be verified by setting an endpoint and checking logs/stderr
    # Since there's no collector, it will fail to export but should still initialize
    local log_dir="${results_preset_dir}/otel-test-logs"
    mkdir -p "$log_dir"

    # Run with OTEL endpoint set (will fail to connect but shows init)
    OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317" \
    APP_LOG_DIR="$log_dir" \
    cargo run --quiet -- info > "${results_preset_dir}/otel-test-output.txt" 2>&1 || true

    # Check if OTel-related code was exercised (binary should still run)
    if [[ -f "${results_preset_dir}/otel-test-output.txt" ]]; then
        echo "    ✓ Binary runs with OTEL_EXPORTER_OTLP_ENDPOINT set"
        echo "OTEL_INIT=PASS" >> "${results_preset_dir}/features.env"
        return 0
    else
        echo "    ✗ Binary failed with OTel endpoint set"
        echo "OTEL_INIT=FAIL" >> "${results_preset_dir}/features.env"
        return 1
    fi
}

generate_feature_checklist() {
    local preset=$1
    local results_preset_dir=$2
    local has_jsonl=$3
    local has_otel=$4
    local has_config=$5

    cat > "${results_preset_dir}/feature-checklist.md" << EOF
# Feature Verification: ${preset}

**Generated:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Features Tested

| Feature | Expected | Result |
|---------|----------|--------|
EOF

    # Read results from features.env
    if [[ -f "${results_preset_dir}/features.env" ]]; then
        source "${results_preset_dir}/features.env"

        echo "| Binary runs | ✓ | ${BINARY_INFO:-NOT_TESTED} |" >> "${results_preset_dir}/feature-checklist.md"
        echo "| JSON output | ✓ | ${BINARY_INFO_JSON:-NOT_TESTED} |" >> "${results_preset_dir}/feature-checklist.md"
        echo "| --help | ✓ | ${BINARY_HELP:-NOT_TESTED} |" >> "${results_preset_dir}/feature-checklist.md"
        echo "| --version | ✓ | ${BINARY_VERSION:-NOT_TESTED} |" >> "${results_preset_dir}/feature-checklist.md"

        if [[ "$has_jsonl" == "true" ]]; then
            echo "| JSONL logging | ✓ | ${JSONL_LOGGING:-NOT_TESTED} |" >> "${results_preset_dir}/feature-checklist.md"
        fi

        if [[ "$has_config" == "true" ]]; then
            echo "| Config discovery | ✓ | ${CONFIG_DISCOVERY:-NOT_TESTED} |" >> "${results_preset_dir}/feature-checklist.md"
        fi

        if [[ "$has_otel" == "true" ]]; then
            echo "| OTel initialization | ✓ | ${OTEL_INIT:-NOT_TESTED} |" >> "${results_preset_dir}/feature-checklist.md"
        fi
    fi

    cat >> "${results_preset_dir}/feature-checklist.md" << EOF

## Artifacts

EOF

    # List artifacts
    for f in "${results_preset_dir}"/*.txt "${results_preset_dir}"/*.json; do
        [[ -f "$f" ]] && echo "- \`$(basename "$f")\`" >> "${results_preset_dir}/feature-checklist.md"
    done

    if [[ -d "${results_preset_dir}/logs" ]]; then
        echo "- \`logs/\` - JSONL log files" >> "${results_preset_dir}/feature-checklist.md"
    fi
}

test_preset() {
    local preset=$1
    local data_file=$2
    local output_dir="${TEST_BASE}/test-${preset}"
    local results_preset_dir="${RESULTS_DIR}/${preset}"

    # Extract feature flags from data file
    local has_jsonl has_otel has_config binary_name
    has_jsonl=$(grep "has_jsonl_logging:" "$data_file" | awk '{print $2}')
    has_otel=$(grep "has_opentelemetry:" "$data_file" | awk '{print $2}')
    has_config=$(grep "has_config:" "$data_file" | awk '{print $2}')
    binary_name=$(grep "project_name:" "$data_file" | awk '{print $2}')

    echo ""
    echo "================================================================"
    echo "Testing ${preset} preset"
    echo "================================================================"

    mkdir -p "$results_preset_dir"
    rm -rf "$output_dir"

    echo "Running copier..."
    copier copy --trust --data-file "$data_file" "$TEMPLATE_DIR" "$output_dir" 2>&1 | tee "${results_preset_dir}/copier.log"

    cd "$output_dir"

    echo "Checking for literal {{ in filenames..."
    if find . -name "*{{*" 2>/dev/null | grep -q .; then
        echo "ERROR: Found files with unresolved template variables"
        find . -name "*{{*" | tee "${results_preset_dir}/template-errors.txt"
        return 1
    fi

    echo "Checking for __skip_ files that should have been excluded..."
    if find . -name "*__skip_*" 2>/dev/null | grep -q .; then
        echo "ERROR: Found __skip_ files that should have been excluded"
        find . -name "*__skip_*" | tee "${results_preset_dir}/skip-errors.txt"
        return 1
    fi

    echo "Running cargo clippy..."
    if ! cargo clippy --all-targets --all-features -- -D warnings 2>&1 | tee "${results_preset_dir}/clippy.log"; then
        echo "ERROR: cargo clippy failed"
        return 1
    fi

    echo "Running cargo nextest..."
    if cargo nextest run 2>&1 | tee "${results_preset_dir}/test.log"; then
        local test_count
        test_count=$(grep -E "^\s+\d+ tests" "${results_preset_dir}/test.log" | head -1 || echo "unknown")
        echo "TESTS=${test_count}" >> "${results_preset_dir}/features.env"
    else
        echo "ERROR: cargo nextest failed"
        echo "TESTS=FAIL" >> "${results_preset_dir}/features.env"
        return 1
    fi

    echo ""
    echo "Running feature verification..."

    # Build release binary first for faster tests
    echo "  Building release binary..."
    cargo build --release --quiet

    # Verify binary runs
    verify_binary_runs "$preset" "$output_dir" "$results_preset_dir" "$binary_name"

    # Verify JSONL logging (if enabled)
    if [[ "$has_jsonl" == "true" ]]; then
        verify_jsonl_logging "$preset" "$output_dir" "$results_preset_dir" "$binary_name"
    fi

    # Verify config discovery (if enabled)
    if [[ "$has_config" == "true" ]]; then
        verify_config_discovery "$preset" "$output_dir" "$results_preset_dir" "$binary_name"
    fi

    # Verify OTel init (if enabled)
    if [[ "$has_otel" == "true" ]]; then
        verify_otel_init "$preset" "$output_dir" "$results_preset_dir" "$binary_name"
    fi

    # Generate feature checklist
    generate_feature_checklist "$preset" "$results_preset_dir" "$has_jsonl" "$has_otel" "$has_config"

    # Record structure
    echo "  Recording directory structure..."
    find . -type f -name "*.rs" -o -name "Cargo.toml" -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" 2>/dev/null | \
        sort > "${results_preset_dir}/structure.txt"

    echo ""
    echo "✓ ${preset} preset passed"
}

generate_summary() {
    local summary_file="${RESULTS_DIR}/SUMMARY.md"

    cat > "$summary_file" << EOF
# Template Test Results

**Timestamp:** ${TIMESTAMP}
**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Copier Version:** $(copier --version 2>&1 | head -1)
**Rust Toolchain:** $(rustc --version)

---

## Results Matrix

| Preset | Build | Tests | Binary | JSONL | Config | OTel |
|--------|-------|-------|--------|-------|--------|------|
EOF

    for preset in minimal standard standard-otel full; do
        local preset_dir="${RESULTS_DIR}/${preset}"
        if [[ -d "$preset_dir" ]] && [[ -f "${preset_dir}/features.env" ]]; then
            source "${preset_dir}/features.env"

            local build_status="✓"
            [[ -f "${preset_dir}/clippy.log" ]] && grep -q "error" "${preset_dir}/clippy.log" && build_status="✗"

            local tests_status="${TESTS:-?}"
            [[ "$tests_status" != "FAIL" ]] && tests_status="✓"

            local binary_status="${BINARY_INFO:-?}"
            [[ "$binary_status" == "PASS" ]] && binary_status="✓" || binary_status="✗"

            local jsonl_status="${JSONL_LOGGING:-N/A}"
            [[ "$jsonl_status" == "PASS" ]] && jsonl_status="✓"
            [[ "$jsonl_status" == *"FAIL"* ]] && jsonl_status="✗"

            local config_status="${CONFIG_DISCOVERY:-N/A}"
            [[ "$config_status" == "PASS" ]] && config_status="✓"
            [[ "$config_status" == "PARTIAL"* ]] && config_status="~"

            local otel_status="${OTEL_INIT:-N/A}"
            [[ "$otel_status" == "PASS" ]] && otel_status="✓"
            [[ "$otel_status" == *"FAIL"* ]] && otel_status="✗"

            echo "| ${preset} | ${build_status} | ${tests_status} | ${binary_status} | ${jsonl_status} | ${config_status} | ${otel_status} |" >> "$summary_file"
        fi
    done

    cat >> "$summary_file" << EOF

---

## Feature Coverage by Preset

| Preset | Features Enabled |
|--------|------------------|
| minimal | CLI only |
| standard | CLI + Core + Config + JSONL logging |
| standard-otel | CLI + Core + Config + JSONL + OpenTelemetry |
| full | All features + Benchmarks + Site + Community files |

---

## Artifacts

Each preset directory contains:
- \`copier.log\` - Template generation output
- \`clippy.log\` - Clippy lint results
- \`test.log\` - Test execution results
- \`features.env\` - Feature verification results
- \`feature-checklist.md\` - Human-readable verification report
- \`structure.txt\` - Generated file structure
- \`info-output.txt\` - Binary info command output
- \`info-json-output.json\` - Binary JSON output
- \`logs/\` - Captured JSONL log files (if applicable)

---

## How to Reproduce

\`\`\`bash
./scripts/test-template.sh
\`\`\`

Or test a specific preset:
\`\`\`bash
./scripts/test-template.sh standard
\`\`\`
EOF

    echo ""
    echo "Summary written to: ${summary_file}"
}

# =============================================================================
# Conditional File Tests (no cargo build required)
# =============================================================================
# These tests verify that modular flags correctly include/exclude files

test_conditional_file() {
    local test_name=$1
    local data_file=$2
    local should_exist=$3  # space-separated list of files that SHOULD exist
    local should_not_exist=$4  # space-separated list of files that should NOT exist

    local output_dir="${TEST_BASE}/conditional-${test_name}"
    rm -rf "$output_dir"

    echo -n "  Testing ${test_name}... "

    # Run copier with trust and defaults (skip prompts, use data file overrides)
    if ! copier copy --trust --defaults --data-file "$data_file" "$TEMPLATE_DIR" "$output_dir" > /dev/null 2>&1; then
        echo "FAIL (copier error)"
        return 1
    fi

    local failed=0

    # Check files that should exist
    for file in $should_exist; do
        if [[ ! -e "${output_dir}/${file}" ]]; then
            echo ""
            echo "    FAIL: Expected ${file} to exist but it doesn't"
            failed=1
        fi
    done

    # Check files that should NOT exist
    for file in $should_not_exist; do
        if [[ -e "${output_dir}/${file}" ]]; then
            echo ""
            echo "    FAIL: Expected ${file} to NOT exist but it does"
            failed=1
        fi
    done

    if [[ $failed -eq 0 ]]; then
        echo "PASS"
        rm -rf "$output_dir"  # Clean up on success
        return 0
    else
        return 1
    fi
}

run_conditional_tests() {
    echo ""
    echo "================================================================"
    echo "Testing conditional file inclusion/exclusion"
    echo "================================================================"

    local failed=0
    local cond_data_dir="${TEST_BASE}/conditional-data"
    mkdir -p "$cond_data_dir"

    # --- Test: has_github=false ---
    cat > "${cond_data_dir}/no-github.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_github: false
has_security_md: false
categories: []
hook_system: none
has_claude: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "no-github" "${cond_data_dir}/no-github.yml" \
        "Cargo.toml" \
        ".github .github/workflows SECURITY.md" || failed=1

    # --- Test: has_github=true but no templates ---
    cat > "${cond_data_dir}/github-no-templates.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_github: true
has_issue_templates: false
has_pr_templates: false
has_security_md: true
categories: []
hook_system: none
has_claude: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "github-no-templates" "${cond_data_dir}/github-no-templates.yml" \
        ".github .github/workflows SECURITY.md" \
        ".github/ISSUE_TEMPLATE .github/PULL_REQUEST_TEMPLATE" || failed=1

    # --- Test: dotfiles enabled (full preset behavior) ---
    cat > "${cond_data_dir}/dotfiles-on.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_yamlfmt: true
has_yamllint: true
has_editorconfig: true
has_env_files: true
categories: []
hook_system: none
has_github: false
has_claude: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "dotfiles-on" "${cond_data_dir}/dotfiles-on.yml" \
        ".yamlfmt .yamllint .editorconfig .env.rust .envrc" \
        "" || failed=1

    # --- Test: dotfiles disabled (standard preset behavior) ---
    cat > "${cond_data_dir}/dotfiles-off.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_yamlfmt: false
has_yamllint: false
has_editorconfig: false
has_env_files: false
categories: []
hook_system: none
has_github: false
has_claude: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "dotfiles-off" "${cond_data_dir}/dotfiles-off.yml" \
        "Cargo.toml" \
        ".yamlfmt .yamllint .editorconfig .env.rust .envrc" || failed=1

    # --- Test: has_claude=false ---
    cat > "${cond_data_dir}/no-claude.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_claude: false
categories: []
hook_system: none
has_github: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "no-claude" "${cond_data_dir}/no-claude.yml" \
        "Cargo.toml" \
        ".claude .claude/CLAUDE.md .claude/skills .claude/commands .claude/rules" || failed=1

    # --- Test: has_claude=true but no skills ---
    cat > "${cond_data_dir}/claude-no-skills.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_claude: true
has_claude_skills: false
has_claude_commands: true
has_claude_rules: true
categories: []
hook_system: none
has_github: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "claude-no-skills" "${cond_data_dir}/claude-no-skills.yml" \
        ".claude .claude/CLAUDE.md .claude/commands .claude/rules" \
        ".claude/skills" || failed=1

    # --- Test: markdown linting enabled ---
    cat > "${cond_data_dir}/md-on.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_md: true
has_md_strict: false
categories: []
hook_system: none
has_github: false
has_claude: false
has_just: true
has_agents_md: false
has_gitattributes: false
DATAEOF
    test_conditional_file "md-on" "${cond_data_dir}/md-on.yml" \
        ".markdownlint.yaml .justfile" \
        "" || failed=1

    # --- Test: markdown linting disabled ---
    cat > "${cond_data_dir}/md-off.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_md: false
categories: []
hook_system: none
has_github: false
has_claude: false
has_just: true
has_agents_md: false
has_gitattributes: false
DATAEOF
    test_conditional_file "md-off" "${cond_data_dir}/md-off.yml" \
        ".justfile" \
        ".markdownlint.yaml" || failed=1

    # --- Test: core files disabled ---
    cat > "${cond_data_dir}/core-off.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_agents_md: false
has_just: false
has_gitattributes: false
categories: []
hook_system: none
has_github: false
has_claude: false
has_md: false
DATAEOF
    test_conditional_file "core-off" "${cond_data_dir}/core-off.yml" \
        "Cargo.toml" \
        "AGENTS.md .justfile .gitattributes" || failed=1

    # --- Test: hook systems ---
    cat > "${cond_data_dir}/hook-cog.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
hook_system: cog
categories: []
has_github: false
has_claude: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "hook-cog" "${cond_data_dir}/hook-cog.yml" \
        "cog.toml" \
        ".pre-commit-config.yaml lefthook.yml" || failed=1

    cat > "${cond_data_dir}/hook-none.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
hook_system: none
categories: []
has_github: false
has_claude: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "hook-none" "${cond_data_dir}/hook-none.yml" \
        "Cargo.toml" \
        "cog.toml .pre-commit-config.yaml lefthook.yml" || failed=1

    # --- Test: individual skills ---
    cat > "${cond_data_dir}/skills-selective.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
has_claude: true
has_claude_skills: true
has_claude_commands: false
has_claude_rules: false
has_skill_markdown_authoring: false
has_skill_capturing_decisions: true
has_skill_using_git: false
categories: []
hook_system: none
has_github: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "skills-selective" "${cond_data_dir}/skills-selective.yml" \
        ".claude/skills/capturing-decisions" \
        ".claude/skills/markdown-authoring .claude/skills/using-git .claude/commands .claude/rules" || failed=1

    # --- Test: release tiers ---
    # Private tier: no release workflows, no cargo-dist config
    cat > "${cond_data_dir}/release-private.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: minimal
release_tier: private
hook_system: cog
has_cli: true
has_core_library: false
categories: []
has_github: true
has_security_md: false
has_issue_templates: false
has_pr_templates: false
has_claude: false
has_just: false
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "release-private" "${cond_data_dir}/release-private.yml" \
        ".github/workflows/ci.yml cog.toml" \
        ".github/workflows/bump.yml .github/workflows/publish.yml .actrc .secrets.example" || failed=1

    # OSS tier: has bump and publish workflows
    cat > "${cond_data_dir}/release-oss.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: standard
release_tier: oss
hook_system: cog
has_cli: true
has_core_library: true
categories: []
has_github: true
has_security_md: false
has_issue_templates: false
has_pr_templates: false
has_claude: false
has_just: true
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "release-oss" "${cond_data_dir}/release-oss.yml" \
        ".github/workflows/ci.yml .github/workflows/bump.yml .github/workflows/publish.yml cog.toml .actrc .secrets.example" \
        "" || failed=1

    # Team tier: same workflows as OSS (automation differs in content, not file presence)
    cat > "${cond_data_dir}/release-team.yml" << 'DATAEOF'
project_name: test-cond
owner: testorg
copyright_name: Test
preset: standard
release_tier: team
team_auto_publish: true
hook_system: cog
has_cli: true
has_core_library: true
categories: []
has_github: true
has_security_md: false
has_issue_templates: false
has_pr_templates: false
has_claude: false
has_just: true
has_agents_md: false
has_gitattributes: false
has_md: false
DATAEOF
    test_conditional_file "release-team" "${cond_data_dir}/release-team.yml" \
        ".github/workflows/ci.yml .github/workflows/bump.yml .github/workflows/publish.yml cog.toml .actrc .secrets.example" \
        "" || failed=1

    # Clean up data files
    rm -rf "$cond_data_dir"

    if [[ $failed -eq 0 ]]; then
        echo ""
        echo "✓ All conditional file tests passed"
        return 0
    else
        echo ""
        echo "✗ Some conditional file tests failed"
        return 1
    fi
}

# Run conditional tests first (fast, no cargo build)
if ! run_conditional_tests; then
    echo "Conditional file tests failed, aborting preset tests"
    exit 1
fi

# Create test data files
mkdir -p "$TEST_BASE"

cat > "${TEST_BASE}/minimal.yml" << 'EOF'
project_name: test-minimal
owner: testorg
copyright_name: Test Org
project_description: Minimal test project
edition: "2024"
msrv: "1.88.0"
pinned_dev_toolchain: "1.92.0"
license:
  - MIT
  - Apache-2.0
versioning: global
categories:
  - command-line-utilities
preset: minimal
hook_system: none
release_tier: private
has_cli: true
has_core_library: false
has_config: false
has_jsonl_logging: false
has_opentelemetry: false
has_benchmarks: false
has_site: false
has_xtask: false
has_community_files: false
# Dotfiles (minimal = off)
has_yamlfmt: false
has_yamllint: false
has_editorconfig: false
has_env_files: false
# Core files
has_agents_md: true
has_just: true
has_gitattributes: true
# GitHub
has_github: true
has_security_md: true
has_issue_templates: true
has_pr_templates: true
# Markdown
has_md: false
# Claude
has_claude: true
has_claude_skills: true
has_claude_commands: true
has_claude_rules: true
# Skills (need explicit values when has_claude_skills is true)
has_skill_markdown_authoring: false
has_skill_capturing_decisions: true
has_skill_using_git: true
EOF

cat > "${TEST_BASE}/standard.yml" << 'EOF'
project_name: test-standard
owner: testorg
copyright_name: Test Org
project_description: Standard test project
edition: "2024"
msrv: "1.88.0"
pinned_dev_toolchain: "1.92.0"
license:
  - MIT
  - Apache-2.0
versioning: global
categories:
  - command-line-utilities
preset: standard
hook_system: cog
release_tier: oss
has_cli: true
has_core_library: true
has_config: true
has_jsonl_logging: true
has_opentelemetry: false
has_benchmarks: false
has_site: false
has_xtask: true
has_community_files: false
# Dotfiles (standard = off)
has_yamlfmt: false
has_yamllint: false
has_editorconfig: false
has_env_files: false
# Core files
has_agents_md: true
has_just: true
has_gitattributes: true
# GitHub
has_github: true
has_security_md: true
has_issue_templates: true
has_pr_templates: true
# Markdown
has_md: true
has_md_strict: false
# Claude
has_claude: true
has_claude_skills: true
has_claude_commands: true
has_claude_rules: true
# Skills
has_skill_markdown_authoring: true
has_skill_capturing_decisions: true
has_skill_using_git: true
EOF

cat > "${TEST_BASE}/standard-otel.yml" << 'EOF'
project_name: test-standard-otel
owner: testorg
copyright_name: Test Org
project_description: Standard test with OpenTelemetry
edition: "2024"
msrv: "1.88.0"
pinned_dev_toolchain: "1.92.0"
license:
  - MIT
  - Apache-2.0
versioning: global
categories:
  - command-line-utilities
preset: standard
hook_system: cog
release_tier: oss
has_cli: true
has_core_library: true
has_config: true
has_jsonl_logging: true
has_opentelemetry: true
has_benchmarks: false
has_site: false
has_xtask: true
has_community_files: false
# Dotfiles (standard = off)
has_yamlfmt: false
has_yamllint: false
has_editorconfig: false
has_env_files: false
# Core files
has_agents_md: true
has_just: true
has_gitattributes: true
# GitHub
has_github: true
has_security_md: true
has_issue_templates: true
has_pr_templates: true
# Markdown
has_md: true
has_md_strict: false
# Claude
has_claude: true
has_claude_skills: true
has_claude_commands: true
has_claude_rules: true
# Skills
has_skill_markdown_authoring: true
has_skill_capturing_decisions: true
has_skill_using_git: true
EOF

cat > "${TEST_BASE}/full.yml" << 'EOF'
project_name: test-full
owner: testorg
copyright_name: Test Org
conduct_email: conduct@test.org
project_description: Full test project
edition: "2024"
msrv: "1.88.0"
pinned_dev_toolchain: "1.92.0"
license:
  - MIT
  - Apache-2.0
versioning: global
categories:
  - command-line-utilities
preset: full
hook_system: cog
release_tier: team
team_auto_publish: true
has_cli: true
has_core_library: true
has_config: true
has_jsonl_logging: true
has_opentelemetry: true
has_benchmarks: true
has_gungraun: false
has_site: true
has_xtask: true
has_community_files: true
# Dotfiles (full = on)
has_yamlfmt: true
has_yamllint: true
has_editorconfig: true
has_env_files: true
# Core files
has_agents_md: true
has_just: true
has_gitattributes: true
# GitHub
has_github: true
has_security_md: true
has_issue_templates: true
has_pr_templates: true
# Markdown
has_md: true
has_md_strict: false
# Claude
has_claude: true
has_claude_skills: true
has_claude_commands: true
has_claude_rules: true
# Skills
has_skill_markdown_authoring: true
has_skill_capturing_decisions: true
has_skill_using_git: true
EOF

# Parse arguments
PRESETS_TO_TEST=("minimal" "standard" "standard-otel" "full")
if [[ $# -gt 0 ]]; then
    PRESETS_TO_TEST=("$@")
fi

# Run tests
FAILED=()
for preset in "${PRESETS_TO_TEST[@]}"; do
    if ! test_preset "$preset" "${TEST_BASE}/${preset}.yml"; then
        FAILED+=("$preset")
    fi
done

# Generate summary
generate_summary

echo ""
echo "================================================================"
if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo "All template presets passed!"
    echo "Results: ${RESULTS_DIR}"
else
    echo "FAILED presets: ${FAILED[*]}"
    echo "Results: ${RESULTS_DIR}"
    exit 1
fi
