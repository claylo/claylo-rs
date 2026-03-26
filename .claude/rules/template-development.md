# Template Development Rules

## The Cardinal Rule

**copier.yaml variables are user-facing prompts.** Every variable you add will be shown to developers creating new projects. If they would say "why are you asking me this?", it doesn't belong there.

## Separation of Concerns

| Belongs in copier.yaml | Does NOT belong in copier.yaml |
|------------------------|--------------------------------|
| Project name, description | Test fixtures |
| Feature flags (logging, config, etc.) | CI/CD configuration for the template |
| License, author info | Development tool settings |
| Preset selection | Grafana/monitoring credentials |
| Things every generated project needs | Things only template maintainers need |

## Before Modifying copier.yaml

1. **Ask:** "Is this something a user generating a project needs to configure?"
2. **Ask:** "Would this prompt make sense to someone who's never seen this template?"
3. **Ask:** "Does this follow the existing variable naming pattern?"
4. If any answer is "no" or "I'm not sure" → **stop and discuss with the user**

## Conditional File and Directory Patterns

Copier evaluates Jinja2 expressions in file and directory **names** automatically.

### Conditional directories (static name)

When a directory name is static and should be conditionally included:

```
{% if has_github %}.github{% endif %}
```

When the condition is **false**, the directory name evaluates to empty string → copier skips it.
When the condition is **true**, the directory name evaluates to `.github` → copier creates it.

### Conditional directories (dynamic name)

When a directory name includes a variable, use a ternary with empty string fallback:

```
{{ project_name if has_cli else "" }}
```

When `has_cli=true`, evaluates to the project name.
When `has_cli=false`, evaluates to empty string → copier skips it.

**Important**: Do NOT nest `{{ }}` inside `{% if %}{% endif %}` for directory names — this pattern doesn't work reliably.

### Conditional files (content has no Jinja)

When a file's **contents** are plain (no template variables), use a conditional filename:

```
{% if has_mcp_server %}serve.rs{% endif %}
```

No `.jinja` suffix — Copier copies the file as-is.

### Conditional files (content has Jinja)

When a file's **contents** use Jinja template variables, add the `.jinja` suffix **outside** the condition:

```
{% if has_mcp_server %}server.rs{% endif %}.jinja
```

The `.jinja` suffix is stripped from the output filename (`_templates_suffix: .jinja`).
When the condition is **false**, the filename evaluates to just `.jinja` → copier skips it.

### Files always present (content has Jinja)

When a file always exists but its contents vary by flags, use `.jinja` suffix only:

```
src/main.rs.jinja        → renders to src/main.rs
src/lib.rs.jinja          → renders to src/lib.rs
Cargo.toml.jinja          → renders to Cargo.toml
```

### Files always present (no Jinja content)

Plain files with no template variables or conditional naming — just use the actual filename:

```
commands/info.rs           → copied verbatim
```

### Key rules

1. The `.jinja` suffix controls **content rendering**
2. The `{% if %}{% endif %}` or `{{ }}` filename controls **file inclusion**
3. For conditional files with Jinja content, `.jinja` must be **outside** the condition
4. For dynamic directory names, use `{{ name if cond else "" }}` — NOT `{% if cond %}{{ name }}{% endif %}`

## Compact Help (HelpShort) Pattern

Generated CLIs use `disable_help_flag = true` on the `Cli` struct and add a custom `-h`/`--help` flag via `clap::ArgAction::HelpShort` so both render the same compact single-line format.

**The help arg is added at the `Command` level in `command()`, NOT as a struct field.** Clap's derive cannot handle `HelpShort` as a struct field — it's a pure exit action with no value to store, and derive insists on populating every bool field before parsing succeeds. Adding it as `pub help: bool` with `HelpShort` causes "required argument: help" errors on every command that doesn't explicitly pass `--help`.

Key files:
- `lib.rs.jinja` — `#[command(disable_help_flag = true)]` on `Cli`, `HelpShort` arg in `command()`
- `main.rs.jinja` — uses `from_arg_matches(&crate::command().get_matches())` instead of `Cli::parse()`

**If adding new CLI args or subcommands:** all parsing must go through `command()`, not `Cli::command()` directly, or the custom help flag won't be present.

## Structural Changes Require Discussion

These changes are **never** okay to make unilaterally:

- Moving copier.yaml (it lives at repo root, period)
- Splitting config files
- Changing the template/ directory structure
- Adding new top-level directories
- Renaming existing variables
- Changing how presets work

## Testing Infrastructure

Template testing lives in `scripts/` and `test/`, not in the template itself.

- Test data files: `scripts/presets/*.yml`
- Test runner: **vendored bats** at `./test/bats/bin/bats` (do NOT use a system `bats`)
- Test helpers: `test/test_helper.bash`
- Test output: `target/template-tests/`
- Formatters: `test/formatters/` — custom bats output formatters

### Running tests

Use `just` commands — they invoke the vendored bats automatically:

| Command | What it runs |
|---------|-------------|
| `just test` | All bats tests |
| `just test-fast` | Conditional file tests only (no cargo build) |
| `just test-presets` | Full preset build tests (slow) |
| `just test-file test/foo.bats` | Single test file |

**Never call `bats` directly.** Always use `./test/bats/bin/bats` or `just test*`.

For reduced output (saves context window tokens), use the agents formatter:

```bash
./test/bats/bin/bats -F "$(pwd)/test/formatters/agents.bash" test/*.bats
```

### Test types

- **Conditional file tests** (`test/conditional_files.bats`): Fast — verify modular flags include/exclude files. No cargo build.
- **Preset tests** (`test/presets.bats`): Slow — full end-to-end with clippy + nextest for each preset.

When adding a new modular flag, add conditional file tests to verify the flag works without a full cargo build cycle.

If you need to test OTEL, Grafana, or other integrations, the test harness goes in `scripts/` and uses environment variables or test data files. It does NOT become a copier.yaml variable.

## Testing Conventions

### Always use test helpers

**Never run raw copier commands in tests.** Always use `generate_project_with_data()` from `test/test_helper.bash` — it handles all required variables (`project_name`, `owner`, `copyright_name`, `conduct_email`, plus computed ones like `crate_name`).

### Conditional file tests must stay fast

Conditional file tests (`test/conditional_files.bats`) must **never** call `cargo_clippy()` or any cargo command. They verify file inclusion/exclusion only — no compilation. Use `assert_file_in_project`, `assert_no_file_in_project`, `assert_file_contains`, `assert_file_not_contains`.

Cargo builds belong in preset tests (`test/presets.bats`) only.

### Test project naming

Test project names must **not** contain dependency crate names as substrings. A project named `serde-test` would cause `use serde_test::...` to be ambiguous between the project crate and the `serde_test` dependency.

Use distinctive prefixes: `cond-feature-on`, `cond-mcp-off`, etc.

### Preset file naming

- Public presets: `scripts/presets/minimal.yml`, `standard.yml`, `full.yml`
- Hidden/variant presets: underscore prefix — `_standard-otel.yml`, `_mcp-server.yml`

### Cargo output in CI/agent contexts

Use `--quiet` on cargo commands when running in test helpers or agent contexts to avoid dumping hundreds of lines of compiler output into the context window. The `cargo_clippy()` helper already does this.

## Jinja Escaping in Templates

### Just/shell `{{ }}` syntax

When template files need Just's own `{{variable}}` syntax, wrap in raw blocks:

```jinja
{% raw %}{{variable}}{% endraw %}
```

### GitHub Actions `${{ }}` syntax

For workflows that mix Jinja template variables with GitHub Actions expressions, use workflow-level `env:` to avoid conflicts. See `.claude/rules/copier-gotchas.md` for details.

### `{% raw %}` cannot be nested

If a file already contains `{% raw %}...{% endraw %}` blocks, do NOT wrap additional content in another `{% raw %}`. The inner `{% endraw %}` will terminate the outer block.

## The "Would This Surprise Someone" Test

Before completing any change, ask: "If the user reviewed this PR without context, would anything make them say 'why did you do it this way?'"

If yes → discuss before proceeding.
