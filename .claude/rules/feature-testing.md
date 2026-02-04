# Feature Testing Requirements

IMPORTANT: Every feature flag (`has_*`) in this template MUST have corresponding tests at two levels: template-level tests that verify file generation, and generated-project tests that verify the feature actually works.

## Two-Tier Testing Approach

| Tier | Location | Purpose | Speed |
|------|----------|---------|-------|
| Template tests | `test/conditional_files.bats` | Verify files are included/excluded based on flags | Fast (no cargo) |
| Generated tests | `template/**/tests/*.rs` or inline `#[cfg(test)]` | Verify feature works when generated | Slow (cargo build) |

## Tier 1: Template Copy Tests

When adding a new `has_*` flag, add tests to `test/conditional_files.bats`:

```bash
@test "has_new_feature=true includes feature files" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-feature-on" "standard.yml" \
        "has_new_feature=true")

    assert_file_in_project "$output_dir" "src/new_feature.rs"
    assert_file_contains "$output_dir" "Cargo.toml" "new-feature-crate"
}

@test "has_new_feature=false excludes feature files" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-feature-off" "standard.yml" \
        "has_new_feature=false")

    assert_no_file_in_project "$output_dir" "src/new_feature.rs"
    assert_file_not_contains "$output_dir" "Cargo.toml" "new-feature-crate"
}
```

Run with `just test-fast` — no cargo build required.

## Tier 2: Generated Project Tests

Generated projects should include tests that verify the feature works. Two patterns:

### Pattern A: Inline `#[cfg(test)]` modules

For library code with internal logic, add tests in the same file:

```rust
// template/crates/.../src/feature.rs.jinja
pub fn process_data(input: &str) -> Result<Output> {
    // implementation
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn process_data_handles_empty_input() {
        let result = process_data("");
        assert!(result.is_ok());
    }
}
```

**Examples in this template:**
- `server.rs` — MCP server unit tests
- `observability.rs` — logging/OTEL unit tests
- `config.rs` — config loading unit tests

### Pattern B: Integration test files

For CLI-facing behavior, use `assert_cmd` in `tests/*.rs`:

```rust
// template/crates/.../tests/feature_integration.rs.jinja
{% if has_new_feature -%}
use assert_cmd::Command;
use predicates::prelude::*;

#[allow(deprecated)]
fn cmd() -> Command {
    Command::cargo_bin(env!("CARGO_PKG_NAME")).unwrap()
}

#[test]
fn feature_command_works() {
    cmd()
        .arg("feature-cmd")
        .assert()
        .success()
        .stdout(predicate::str::contains("expected output"));
}
{% endif %}
```

**Examples in this template:**
- `cli.rs` — CLI integration tests (help, version, flags)
- `config_integration.rs` — config discovery from user perspective

## When to Use Which Pattern

| Scenario | Pattern |
|----------|---------|
| Internal library functions | Inline `#[cfg(test)]` |
| Data structures / serialization | Inline `#[cfg(test)]` |
| CLI commands / flags | Integration tests (`tests/*.rs`) |
| User-visible behavior | Integration tests |
| Error messages / output format | Integration tests with `predicates` |

## Test Dependencies

Generated projects include these test dependencies by default:

```toml
[dev-dependencies]
assert_cmd = "..."     # CLI subprocess testing
predicates = "..."     # Output assertions
tempfile = "..."       # Temporary directories
insta = "..."          # Snapshot testing (optional)
```

## Checklist for New Features

Before a feature flag is considered complete:

- [ ] Template test verifies files included when flag is true
- [ ] Template test verifies files excluded when flag is false
- [ ] Template test verifies Cargo.toml dependencies added/removed
- [ ] Generated code has inline unit tests for internal logic
- [ ] Generated code has integration tests for user-facing behavior
- [ ] `just test-fast` passes (template copy tests)
- [ ] `just test-presets` passes (full cargo builds)

## Running Tests

```bash
# Fast: verify file inclusion only
just test-fast

# Full: build and test all presets
just test-presets

# Single file
just test-file test/conditional_files.bats

# Reduced output for agents
./test/bats/bin/bats -F "$(pwd)/test/formatters/agents.bash" test/*.bats
```

## Coverage Expectations

Generated projects should have meaningful test coverage:

- CLI commands: All subcommands exercised
- Feature modules: Core logic paths covered
- Error cases: Invalid input, missing files, parse failures
- Configuration: Discovery, parsing, precedence
