# Presets

Each preset configures a coherent set of defaults.
Override any setting with `+flag` or `-flag`.


## Contents

- [Minimal](#minimal)
- [Library](#library)
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


## Library

A publishable library crate. Flat `src/` layout, no workspace, no CLI.

```bash
claylo-rs new ./my-lib --preset library
```

**Use when:**

- You're building a library for others to consume
- You don't need a CLI binary
- You want benchmarks and release automation without binary distribution

**Generates:**

```
my-lib/
├── src/
│   ├── lib.rs             # Library entry point
│   └── error.rs           # Error types (thiserror)
├── benches/               # Divan benchmarks
├── .claude/
├── Cargo.toml             # [package], not [workspace]
├── deny.toml
└── .justfile
```

**What's enabled:**

| Feature | Enabled |
|---------|---------|
| CLI binary | ✗ |
| Core library | ✓ |
| Config support | ✗ |
| JSONL logging | ✗ |
| Benchmarks | ✓ |
| Release automation | ✓ |
| Binary distribution | ✗ |

The library preset generates a flat crate (`[package]` Cargo.toml with `src/` at root) rather than a workspace. Release automation creates changelogs and tags but skips the binary distribution pipeline (npm, Homebrew, cross-platform builds) since there's no binary to distribute.


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
├── docs/                 # Starlight content source
├── site/                 # Astro Starlight site
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
| Documentation site | ✓ |
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
├── site/                 # Astro Starlight documentation site
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
| Documentation site | ✓ |
| Editor configs | ✓ |
| Environment files | ✓ |


## Comparison Table

<!-- BEGIN GENERATED: preset-comparison -->
| Feature | Full | Library | Minimal | Standard |
|---------|----------|----------|----------|----------|
| `has_agents_md` | ✓ | ✓ | ✓ | ✓ |
| `has_attestations` | ✓ | ✗ | ✓ | ✓ |
| `has_benchmarks` | ✓ | ✓ | ✗ | ✗ |
| `has_claude` | ✓ | ✓ | ✓ | ✓ |
| `has_cli` | ✓ | ✗ | ✓ | ✓ |
| `has_coda` | ✓ | ✓ | ✓ | ✓ |
| `has_community_files` | ✓ | ✗ | ✗ | ✗ |
| `has_config` | ✓ | ✗ | ✗ | ✓ |
| `has_core_library` | ✓ | ✓ | ✗ | ✓ |
| `has_editorconfig` | ✓ | ✗ | ✗ | ✗ |
| `has_env_files` | ✓ | ✗ | ✗ | ✗ |
| `has_gitattributes` | ✓ | ✓ | ✓ | ✓ |
| `has_github` | ✓ | ✓ | ✓ | ✓ |
| `has_gungraun` | ✗ | ✗ | ✗ | ✗ |
| `has_issue_templates` | ✓ | ✓ | ✓ | ✓ |
| `has_jsonl_logging` | ✓ | ✗ | ✗ | ✓ |
| `has_mcp_server` | ✗ | ✗ | ✗ | ✗ |
| `has_md` | ✓ | ✓ | ✗ | ✓ |
| `has_md_strict` | ✗ | ✗ | ✗ | ✗ |
| `has_opentelemetry` | ✓ | ✗ | ✗ | ✗ |
| `has_pr_templates` | ✓ | ✓ | ✓ | ✓ |
| `has_releases` | ✓ | ✓ | ✗ | ✓ |
| `has_roadmap_votes` | ✗ | ✗ | ✗ | ✗ |
| `has_security_md` | ✓ | ✓ | ✓ | ✓ |
| `has_site` | ✓ | ✗ | ✗ | ✓ |
| `has_yamlfmt` | ✓ | ✗ | ✗ | ✗ |
| `has_yamllint` | ✓ | ✗ | ✗ | ✗ |
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

This adds the tokio async runtime implicitly (MCP servers need it for stdio transport).