# claylo-rs

An opinionated Rust project template for building production-ready CLI tools and libraries.

## What You Get

- **Workspace layout** with separate CLI and core library crates
- **Hierarchical config discovery** (project + user config files)
- **Structured JSONL logging** with daily rotation (never writes to stdout)
- **Optional OpenTelemetry** trace export (opt-in, adds tokio dependency)
- **xtask automation** for man pages, shell completions, and installation
- **Optional benchmarking** stack (Divan + Gungraun)

## Quick Start

```bash
# Install copier if you haven't already
uv tool install copier

# Create a new project
copier copy gh:claylo/claylo-rs my-new-project

# Or from a local clone
copier copy . my-new-project
```

## Presets

The template offers three presets that configure sensible defaults:

| Preset | What's Included |
|--------|-----------------|
| **Minimal** | CLI binary only |
| **Standard** | CLI + core library + config + JSONL logging + xtask |
| **Full** | Everything including benchmarks and site placeholder |

For OpenTelemetry support, use the `standard` preset and enable `has_opentelemetry`:

```bash
# Use a specific preset (you'll be prompted if not specified)
copier copy --data preset=minimal . my-cli
copier copy --data preset=standard . my-tool
copier copy --data preset=full . my-app

# Standard with OpenTelemetry tracing
copier copy --data preset=standard --data has_opentelemetry=true . my-otel-tool
```

## Template Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `project_name` | string | required | Project name (lowercase with hyphens) |
| `owner` | string | required | GitHub org/username |
| `copyright_name` | string | required | Name for license copyright |
| `project_description` | string | "A modern..." | Project description |
| `edition` | string | "2024" | Rust edition (2021, 2024) |
| `msrv` | string | "1.88.0" | Minimum Supported Rust Version |
| `license` | multi-select | MIT + Apache-2.0 | License(s) to include |
| `preset` | choice | standard | `minimal`, `standard`, or `full` |

### Feature Flags (Override Preset Defaults)

| Flag | Default | Description |
|------|---------|-------------|
| `has_cli` | true | Include CLI binary crate |
| `has_core_library` | preset-based | Include `-core` library crate |
| `has_config` | preset-based | Include configuration file support |
| `has_jsonl_logging` | true (if CLI) | Structured JSONL file logging |
| `has_opentelemetry` | false | OpenTelemetry trace export (adds tokio) |
| `has_benchmarks` | full only | Benchmark infrastructure |
| `has_site` | full only | Site directory placeholder |
| `has_community_files` | false | Include CODE_OF_CONDUCT.md and CONTRIBUTING.md |

### Git Hooks

| Option | Default | Description |
|--------|---------|-------------|
| `hook_system` | none | Git hook management: `pre-commit`, `lefthook`, or `none` |

- **pre-commit**: [pre-commit.com](https://pre-commit.com/) framework
- **lefthook**: Fast, polyglot hook runner
- **none** (default): No git hooks

### GitHub Integration

| Flag | Default | Description |
|------|---------|-------------|
| `has_github` | true | Include `.github/` directory (workflows, templates, etc.) |
| `has_security_md` | true | Include SECURITY.md for vulnerability reporting |
| `has_issue_templates` | true | Include GitHub issue templates |
| `has_pr_templates` | true | Include GitHub PR templates |

### Dotfiles (full preset only by default)

| Flag | Default | Description |
|------|---------|-------------|
| `has_yamlfmt` | full only | Include `.yamlfmt` config |
| `has_yamllint` | full only | Include `.yamllint` config |
| `has_editorconfig` | full only | Include `.editorconfig` for consistent editor settings |
| `has_env_files` | full only | Include `.env`, `.env.rust`, and `.envrc` files |

### Core Files

| Flag | Default | Description |
|------|---------|-------------|
| `has_agents_md` | true | Include AGENTS.md for AI agent instructions |
| `has_just` | true | Include `.justfile` for task automation |
| `has_gitattributes` | true | Include `.gitattributes` for line ending normalization |

### Markdown Linting

| Flag | Default | Description |
|------|---------|-------------|
| `has_md` | standard/full | Include lenient markdown linting (SEMBR-friendly) |
| `has_md_strict` | false | Use stricter markdown rules (1 blank line max, dash lists) |

When enabled, adds `just mdlint` and `just mdfix` recipes.

### Claude Code Integration

| Flag | Default | Description |
|------|---------|-------------|
| `has_claude` | true | Include `.claude/` directory with agent configuration |
| `has_claude_skills` | true | Include `.claude/skills/` (skip if you have global skills) |
| `has_claude_commands` | true | Include `.claude/commands/` (skip if you have global commands) |
| `has_claude_rules` | true | Include `.claude/rules/` (skip if you have global rules) |
| `has_skill_markdown_authoring` | auto | Include markdown-authoring skill (when `has_md`) |
| `has_skill_capturing_decisions` | true | Include capturing-decisions (ADR) skill |
| `has_skill_using_git` | true | Include using-git skill |

> **Note:** Community health files (CODE_OF_CONDUCT.md, CONTRIBUTING.md, etc.) are excluded by default. Consider using a [`.github` repository](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) to share these files across all your repositories instead of duplicating them in each project.

## Using a Data File

For reproducible project generation, create a YAML data file:

```yaml
# my-project.yml
project_name: my-awesome-cli
owner: myorg
copyright_name: My Organization
project_description: A CLI tool that does amazing things
msrv: "1.88.0"
license:
  - MIT
  - Apache-2.0
preset: standard
```

Then generate:

```bash
copier copy --trust --data-file my-project.yml . ./my-awesome-cli
```

## Updating Existing Projects

Copier tracks template answers in `.repo.yml`. To apply template updates:

```bash
cd my-existing-project
copier update
```

This performs a three-way merge, preserving your changes while applying template updates.

### Bulk Updates

To scan multiple projects for available updates:

```bash
# From the template repo
./scripts/update-projects.sh ~/my-projects

# Apply updates (creates branches)
./scripts/update-projects.sh -u ~/my-projects

# Filter to only this template's projects
./scripts/update-projects.sh -f claylo-rs ~/my-projects
```

## Project Structure

Generated projects have this layout:

```
my-project/
├── .github/
│   └── workflows/        # CI, dependabot
├── crates/
│   ├── my-project/       # CLI binary (if has_cli)
│   └── my-project-core/  # Core library (if has_core_library)
├── xtask/                # Build automation (if has_xtask)
├── Cargo.toml            # Workspace manifest
├── deny.toml             # cargo-deny config
└── .justfile             # Task runner recipes
```

## Logging and Tracing

When `has_jsonl_logging` is enabled, the generated project uses Rust's `tracing` crate for structured logging:

- **All tracing macros work**: `debug!`, `info!`, `warn!`, `error!`, `#[instrument]`
- Logs are written as JSONL to daily-rotated files
- **Never writes to stdout** (safe for MCP servers and tools that use stdout for IPC)
- Falls back to stderr if no writable log directory is found

Control log levels with:
- `-v` flag → `debug` level
- `-vv` flag → `trace` level
- `--quiet` flag → `error` only
- `RUST_LOG` env var → fine-grained control (e.g., `RUST_LOG=my_crate=debug`)

Log location (first writable wins):
1. `/var/log/<project>.jsonl` (Unix, requires write access)
2. `~/.local/share/<project>/logs/<project>.jsonl`
3. Current directory

Override with:
- `APP_LOG_PATH` - full file path
- `APP_LOG_DIR` - directory only

## OpenTelemetry (Optional)

OpenTelemetry adds **distributed trace export**—it does not enable tracing itself. Tracing macros and `#[instrument]` work with just `has_jsonl_logging`.

When `has_opentelemetry` is enabled:

- Adds `opentelemetry`, `opentelemetry_sdk`, `opentelemetry-otlp` crates
- Adds `tokio` runtime dependency
- Trace export is **opt-in** at runtime via `OTEL_EXPORTER_OTLP_ENDPOINT`

This is useful for tools that may eventually need distributed tracing to external collectors (Jaeger, Tempo, etc.), but most projects should leave it disabled to avoid the tokio dependency.

### Zero-Cost Tracing

For developers coming from languages like Python, Java, or Node.js: Rust's `tracing` crate is **zero-cost when no subscriber is registered**.

When you use `tracing` macros but don't initialize the observability system, the compiler optimizes these calls away entirely—they become no-ops with zero runtime overhead. This means you can:

- Instrument your code liberally without worrying about performance
- Ship the same binary for all environments
- Enable detailed tracing only when needed (debugging, profiling, production incidents)

This is fundamentally different from logging frameworks in garbage-collected languages, where logging calls always have some overhead even when disabled.

## Development

### Prerequisites

- Rust (see `rust-toolchain.toml` for pinned version)
- [just](https://github.com/casey/just) - task runner
- [cargo-nextest](https://nexte.st/) - fast test runner
- [copier](https://copier.readthedocs.io/) - `uv tool install copier`

### Testing the Template

```bash
# Run all tests (conditional file tests + preset builds)
./scripts/test-template.sh

# Test a specific preset only
./scripts/test-template.sh standard

# Test manually with a data file
copier copy --trust --data-file my-test.yml . target/template-tests/my-test
cd target/template-tests/my-test && cargo check --all-targets
```

The test script runs two types of tests:
1. **Conditional file tests** - Fast verification that modular flags include/exclude files correctly (no cargo build)
2. **Preset tests** - Full build + clippy + nextest + feature verification for each preset

### Template Development

Template files use Jinja2 syntax with `.jinja` suffix. Key patterns:

- Conditional files: `{{"file.rs" if condition else "__skip_file__.rs"}}.jinja`
- Conditional directories: `{{"dirname" if condition else "__skip_dirname__"}}/`
- Raw blocks for GitHub Actions: `{% raw %}${{ github.token }}{% endraw %}`

## License

This template is dual-licensed under MIT and Apache-2.0.

## Acknowledgements

This template was developed with assistance from [Claude Code](https://claude.ai/claude-code), Anthropic's AI coding assistant.
