# Template Development

Contributing to the claylo-rs template.


## Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [Template Syntax](#template-syntax)
- [Adding Features](#adding-features)
- [Coding Standards](#coding-standards)


## Prerequisites

- Rust (see `rust-toolchain.toml` for pinned version)
- [just](https://github.com/casey/just) — task runner
- [cargo-nextest](https://nexte.st/) — fast test runner
- [copier](https://copier.readthedocs.io/) — `pipx install copier` or `uv tool install copier`
- Bash 4+ (macOS: `brew install bash`)


## Project Structure

```
claylo-rs/
├── bin/
│   └── claylo-rs          # Wrapper script
├── template/              # Copier template source
│   ├── crates/            # Generated crate structure
│   ├── .github/           # Generated workflows
│   └── *.jinja            # Jinja2 template files
├── scripts/
│   ├── presets/           # Preset YAML data files
│   └── *.sh               # Helper scripts
├── test/
│   ├── bats/              # Vendored bats test runner
│   ├── formatters/        # Custom bats formatters
│   ├── *.bats             # Test suites
│   └── test_helper.bash   # Test utilities
├── docs/
│   ├── decisions/         # Architecture Decision Records
│   ├── plans/             # Implementation plans
│   └── specs/             # Feature specifications
├── copier.yaml            # Template configuration
└── .justfile              # Development recipes
```


## Testing

All tests use the vendored bats runner.
Never call `bats` directly — use `just` commands.

### Run All Tests

```bash
just test
```

### Fast Tests Only

Conditional file tests verify modular flags without cargo builds:

```bash
just test-fast
```

### Preset Tests Only

Full end-to-end: generate, build, clippy, nextest:

```bash
just test-presets
```

### Single Test File

```bash
just test-file test/conditional_files.bats
```

### Reduced Output

For CI or when context window tokens matter:

```bash
./test/bats/bin/bats -F "$PWD/test/formatters/agents.bash" test/*.bats
```

### Test Output Location

Tests write to `target/template-tests/`, not `/tmp`.


## Template Syntax

Template files use Jinja2. Key patterns:

### Conditional Files

When file contents have no Jinja, use conditional filename only:

```
commands/{{"serve.rs" if has_mcp_server else "__skip_serve__.rs"}}
```

When file contents use Jinja, add `.jinja` suffix:

```
src/{{"server.rs" if has_mcp_server else "__skip_server__.rs"}}.jinja
```

### Conditional Directories

```
template/crates/{{project_name if has_cli else "__skip_cli__"}}/
```

Names starting with `__skip_` are excluded via `_exclude` in copier.yaml.

### Escaping for GitHub Actions

```jinja
{% raw %}${{ github.token }}{% endraw %}
```

### Always-Present Files with Jinja Content

```
src/main.rs.jinja          → renders to src/main.rs
Cargo.toml.jinja           → renders to Cargo.toml
```


## Adding Features

### 1. Add the Flag

In `copier.yaml`:

```yaml
has_my_feature:
  type: bool
  default: false
  help: Enable my feature
```

### 2. Add Preset Defaults

In `scripts/presets/*.yml`:

```yaml
has_my_feature: true  # or false
```

### 3. Create Conditional Files

Add files to `template/` with conditional names.

### 4. Add Tests

In `test/conditional_files.bats`:

```bash
@test "my_feature flag includes expected files" {
  generate_with_data "has_my_feature=true"
  assert_file_exists "path/to/expected/file"
}

@test "my_feature flag excludes files when disabled" {
  generate_with_data "has_my_feature=false"
  assert_file_not_exists "path/to/expected/file"
}
```

### 5. Update Documentation

- Add flag to `docs/reference.md`
- Update `docs/presets.md` if preset defaults change


## Coding Standards

### Generated Code

Generated Rust code must pass:

```bash
cargo clippy --all-targets --all-features -- -D warnings
cargo fmt --all -- --check
cargo nextest run
```

### Template Files

- Run `just fmt` and `just lint` after modifying `copier.yaml`
- Keep Jinja logic simple — complex logic belongs in Python or bash
- Test both enabled and disabled states

### Commits

Follow conventional commits. The template enforces this via hooks when `hook_system` is set.

### copier.yaml

Every variable becomes a user-facing prompt.
Before adding a variable, ask:
"Would a developer generating a project understand why they're being asked this?"

Test fixtures, CI configuration, and development tooling never belong in copier.yaml.
