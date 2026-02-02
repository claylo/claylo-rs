# Presets

Each preset configures a coherent set of defaults.
Override any setting with `+flag` or `-flag`.


## Contents

- [Minimal](#minimal)
- [Standard](#standard)
- [Full](#full)
- [Comparison Table](#comparison-table)


## Minimal

Just the binary. No runtime dependencies beyond `clap`.

```bash
claylo-rs new ./my-tool --preset minimal
```

**Use when:**

- You need a single-file CLI
- Dependencies must stay minimal
- You'll add features as needed

**Generates:**

```
my-tool/
├── crates/
│   └── my-tool/          # CLI binary only
├── Cargo.toml
├── deny.toml
└── .justfile
```

**What's enabled:**

| Feature | Enabled |
|---------|---------|
| CLI binary | ✓ |
| Core library | ✗ |
| Config support | ✗ |
| JSONL logging | ✗ |
| xtask | ✗ |
| Benchmarks | ✗ |


## Standard

The "you'll thank yourself later" tier.
Workspace layout with separate CLI and library crates.

```bash
claylo-rs new ./my-tool --preset standard
```

**Use when:**

- You're building a real tool
- You want testable library code
- You need config file support
- You plan to maintain this

**Generates:**

```
my-tool/
├── crates/
│   ├── my-tool/          # CLI binary
│   └── my-tool-core/     # Library crate
├── xtask/                # Build automation
├── .claude/              # AI agent config
├── Cargo.toml
├── deny.toml
└── .justfile
```

**What's enabled:**

| Feature | Enabled |
|---------|---------|
| CLI binary | ✓ |
| Core library | ✓ |
| Config support | ✓ |
| JSONL logging | ✓ |
| xtask | ✓ |
| Benchmarks | ✗ |
| GitHub workflows | ✓ |
| Markdown linting | ✓ |


## Full

Everything.
For projects that will outlive your current job.

```bash
claylo-rs new ./my-tool --preset full
```

**Use when:**

- Performance matters and you'll measure it
- You want consistent editor settings across contributors
- You're establishing team conventions
- This project is a long-term investment

**Generates:**

```
my-tool/
├── crates/
│   ├── my-tool/
│   └── my-tool-core/
├── benches/              # Divan benchmarks
├── xtask/
├── site/                 # Documentation site placeholder
├── .claude/
├── .editorconfig
├── .yamlfmt
├── .yamllint
├── .env
├── .envrc
├── Cargo.toml
├── deny.toml
└── .justfile
```

**What's enabled:**

| Feature | Enabled |
|---------|---------|
| CLI binary | ✓ |
| Core library | ✓ |
| Config support | ✓ |
| JSONL logging | ✓ |
| xtask | ✓ |
| Benchmarks | ✓ |
| Site placeholder | ✓ |
| Editor configs | ✓ |
| Environment files | ✓ |


## Comparison Table

<!-- BEGIN GENERATED: preset-comparison -->
| Feature | Full | Minimal | Standard |
|---------|----------|----------|----------|
| `has_agents_md` | ✓ | ✓ | ✓ |
| `has_benchmarks` | ✓ | ✗ | ✗ |
| `has_claude` | ✓ | ✓ | ✓ |
| `has_claude_commands` | ✓ | ✓ | ✓ |
| `has_claude_skills` | ✓ | ✓ | ✓ |
| `has_cli` | ✓ | ✓ | ✓ |
| `has_community_files` | ✓ | ✗ | ✗ |
| `has_config` | ✓ | ✗ | ✓ |
| `has_core_library` | ✓ | ✗ | ✓ |
| `has_editorconfig` | ✓ | ✗ | ✗ |
| `has_env_files` | ✓ | ✗ | ✗ |
| `has_gitattributes` | ✓ | ✓ | ✓ |
| `has_github` | ✓ | ✓ | ✓ |
| `has_gungraun` | ✗ | ✗ | ✗ |
| `has_issue_templates` | ✓ | ✓ | ✓ |
| `has_jsonl_logging` | ✓ | ✗ | ✓ |
| `has_just` | ✓ | ✓ | ✓ |
| `has_mcp_server` | ✗ | ✗ | ✗ |
| `has_md` | ✓ | ✗ | ✓ |
| `has_md_strict` | ✗ | ✗ | ✗ |
| `has_opentelemetry` | ✓ | ✗ | ✗ |
| `has_pr_templates` | ✓ | ✓ | ✓ |
| `has_security_md` | ✓ | ✓ | ✓ |
| `has_site` | ✓ | ✗ | ✗ |
| `has_skill_capturing_decisions` | ✓ | ✓ | ✓ |
| `has_skill_markdown_authoring` | ✓ | ✗ | ✓ |
| `has_skill_using_git` | ✓ | ✓ | ✓ |
| `has_xtask` | ✓ | ✗ | ✓ |
| `has_yamlfmt` | ✓ | ✗ | ✗ |
| `has_yamllint` | ✓ | ✗ | ✗ |
<!-- END GENERATED: preset-comparison -->

### OpenTelemetry

OpenTelemetry is off by default in all presets because it adds a tokio dependency.
Enable it explicitly:

```bash
claylo-rs new ./my-tool --preset standard +otel
```

### MCP Server

MCP server scaffolding is also off by default.
Enable it when you need a Model Context Protocol server:

```bash
claylo-rs new ./my-tool --preset standard +mcp
```

This adds `has_opentelemetry` implicitly (MCP servers need async runtime).