# Reference

Complete list of `claylo-rs` options and template variables.


## Contents

- [Command-Line Options](#command-line-options)
- [Feature Flags](#feature-flags)
- [Project Identity](#project-identity)
- [Presets](#presets)
- [Git Hooks](#git-hooks)
- [GitHub Integration](#github-integration)
- [Dotfiles](#dotfiles)
- [Core Files](#core-files)
- [Markdown Linting](#markdown-linting)
- [Claude Code Integration](#claude-code-integration)


## Command-Line Options

```bash
claylo-rs <command> [options] [+feature-flags]
```

### Commands

| Command | Description |
|---------|-------------|
| `new <dest>` | Create a new project |
| `update [dest]` | Update an existing project (defaults to current directory) |
| `usage` | Print template capability manifest (for AI agents) |

### Options

| Option | Description |
|--------|-------------|
| `--preset <name>` | `minimal`, `library`, `standard`, or `full` |
| `--lint <level>` | `strict`, `standard`, or `relaxed` |
| `--hook <system>` | `pre-commit`, `lefthook`, or `none` |
| `--owner <name>` | GitHub org or username |
| `--copyright <name>` | Copyright holder name |
| `--desc <text>` | Project description |
| `--data key=value` | Pass arbitrary data (repeatable) |
| `--data-file <path>` | YAML file with default values |
| `--dry-run` | Preview without writing files |
| `--local` | Use local template directory (development) |
| `--vcs-ref <ref>` | Template git ref to use |
| `--conflict <mode>` | `rej` or `inline` (default: `inline`, update only) |
| `-y`, `--yes` | Skip confirmation prompts |
| `-V`, `--version` | Print version and exit |

### Feature Flag Syntax

Enable with `+`, disable with `-`. Chain multiple flags:

```bash
claylo-rs new ./my-tool +otel+mcp-bench
```


## Feature Flags

Override preset defaults with these flags.

| Flag | Alias | Default | Description |
|------|-------|---------|-------------|
| `has_cli` | `cli` | true | CLI binary crate |
| `has_core_library` | `core` | preset | Core library crate |
| `has_config` | `config` | preset | Configuration file support |
| `has_jsonl_logging` | `jsonl` | true (if CLI) | Structured JSONL file logging |
| `has_opentelemetry` | `otel` | false | OpenTelemetry trace export |
| `has_mcp_server` | `mcp` | false | MCP server scaffolding |
| `has_inquire` | `inquire` | false | Interactive prompts (Confirm, Select, Text) |
| `has_indicatif` | `indicatif` | false | Progress bars and spinners |
| `has_benchmarks` | `bench` | library/full | Benchmark infrastructure |
| `has_gungraun` | `gungraun` | false | Gungraun benchmark generator |
| `has_site` | `site` | standard/full | Astro Starlight documentation site |
| `site_deploy` | — | `github_pages` | Deploy target: `github_pages`, `cloudflare_github_actions`, `cloudflare` |
| `site_package_manager` | — | `npm` | Package manager: `npm`, `pnpm`, `bun`, `yarn` |
| `has_community_files` | `community` | false | CODE_OF_CONDUCT.md, CONTRIBUTING.md |
| `has_releases` | `releases` | preset | Release automation (git-cliff, release workflow) |
| `has_attestations` | `attestations` | `has_binary_dist` | Sigstore artifact attestations |
| `has_coda` | `coda` | true | gh-coda repo settings automation |
| `has_roadmap_votes` | `roadmap_votes` | false | Roadmap voting workflow |
| `has_binary_dist` | — | computed | Binary distribution (npm, Homebrew, CD workflow) |

`has_binary_dist` is computed from `has_cli and has_releases`. When true, the CD workflow builds cross-platform binaries and publishes to npm, Homebrew, crates.io, deb, and rpm. The library preset has `has_releases=true` but `has_cli=false`, so it gets release automation (changelogs, tags) without the binary distribution pipeline.


## Project Identity

These variables identify your project.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_name` | string | required | Project name (lowercase, hyphens) |
| `owner` | string | required | GitHub org or username |
| `copyright_name` | string | required | Name for license copyright |
| `project_description` | string | "A modern..." | One-line description |
| `conduct_email` | string | required (if `+community`) | Contact email for code of conduct |
| `edition` | string | "2024" | Rust edition |
| `msrv` | string | "1.89.0" | Minimum Supported Rust Version |
| `pinned_dev_toolchain` | string | "1.94.0" | Pinned development toolchain |
| `license` | multi-select | MIT + Apache-2.0 | License(s) to include |
| `categories` | multi-select | [] | crates.io categories |


## Presets

Each preset configures sensible defaults.
Override any setting with feature flags.

| Preset | CLI | Core Library | Config | Logging | Benchmarks | Site |
|--------|-----|--------------|--------|---------|------------|------|
| `minimal` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `library` | ✗ | ✓ | ✗ | ✗ | ✓ | ✗ |
| `standard` | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| `full` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

See [presets.md](presets.md) for detailed breakdowns.


## Git Hooks

| Option | Values | Description |
|--------|--------|-------------|
| `hook_system` | `none`, `pre-commit`, `lefthook` | Git hook framework |

- **none** (default): No hooks. Run checks manually.
- **pre-commit**: [pre-commit.com](https://pre-commit.com/) framework
- **lefthook**: [Lefthook](https://github.com/evilmartians/lefthook), fast polyglot runner


## GitHub Integration

| Flag | Alias | Default | Description |
|------|-------|---------|-------------|
| `has_github` | `github` | true | `.github/` directory |
| `has_security_md` | `security_md` | true | SECURITY.md |
| `has_issue_templates` | `issues` | true | Issue templates |
| `has_pr_templates` | `prs` | true | PR templates |

Consider using a [`.github` repository](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) to share community health files across repositories.


## Dotfiles

These files are included in `full` preset by default.

| Flag | Alias | Default | Description |
|------|-------|---------|-------------|
| `has_yamlfmt` | `yamlfmt` | full | `.yamlfmt` config |
| `has_yamllint` | `yamllint` | full | `.yamllint` config |
| `has_editorconfig` | `editorconfig` | full | `.editorconfig` |
| `has_env_files` | `env` | full | `.env`, `.env.rust`, `.envrc` |


## Core Files

| Flag | Alias | Default | Description |
|------|-------|---------|-------------|
| `has_agents_md` | `agents_md` | true | AGENTS.md for AI agent instructions |
| `has_gitattributes` | `gitattributes` | true | `.gitattributes` |


## Markdown Linting

| Flag | Alias | Default | Description |
|------|-------|---------|-------------|
| `has_md` | `md` | standard/full | Lenient markdown linting (SEMBR-friendly) |
| `has_md_strict` | `md_strict` | false | Stricter rules (1 blank line max, dash lists) |

When enabled, adds `just mdlint` and `just mdfix` recipes.


## Claude Code Integration

| Flag | Alias | Default | Description |
|------|-------|---------|-------------|
| `has_claude` | `claude` | true | `.claude/settings.json` with agent permissions |

Generates a `.claude/settings.json` with sensible `allowedTools` for the generated project (cargo, git, just, etc.).


## Lint Level

| Level | Clippy Lints | Description |
|-------|--------------|-------------|
| `strict` | `all` + `nursery` | Aggressive warnings, including unstable lints |
| `standard` | `all` | Stable clippy warnings only |
| `relaxed` | Rust defaults | No extra clippy lint groups |

```bash
claylo-rs new ./my-tool --lint strict
```


## Generated CLI Features

The generated CLI includes these subcommands based on enabled features.

### info

Always included. Shows package version and build information.

```bash
my-tool info          # Human-readable output
my-tool info --json   # JSON output for scripting
```

### doctor

Included when `has_config=true`. Diagnoses configuration and environment.

```bash
my-tool doctor        # Human-readable diagnostic output
my-tool doctor --json # JSON output
```

Shows:
- **Configuration status** — Whether a config file was found and its path
- **XDG directories** — Config, cache, data, and local data paths
- **Environment variables** — RUST_LOG, XDG overrides, OTEL endpoint (if enabled)

When `has_inquire=true`, offers to create a default config file if none exists.
When `has_indicatif=true`, shows a spinner while gathering diagnostics.

### serve

Included when `has_mcp_server=true`. Runs the MCP server over stdio.

```bash
my-tool serve
```
