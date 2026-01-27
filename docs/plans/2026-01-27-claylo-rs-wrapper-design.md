# Design: `bin/claylo-rs` Copier Wrapper

**Date:** 2026-01-27
**Branch:** `feat/wrapper`
**Status:** Design approved, ready for implementation

---

## Purpose

Wrap copier's verbose CLI into a short, memorable command with pandoc-style
feature toggles. The raw copier invocation for this template requires dozens
of `--data` flags — this script makes it painless.

---

## Invocation Syntax

```bash
# Create a new project
claylo-rs new ./my-cool-cli --preset full --lint strict +otel+benchmarks-site

# Create with defaults (standard preset)
claylo-rs new ./my-cool-cli

# Update an existing project
claylo-rs update ./my-cool-cli +otel-site

# Update current directory
claylo-rs update . +benchmarks

# Preview without writing
claylo-rs new ./my-app --preset full --dry-run +otel
```

---

## Subcommands

| Subcommand | Maps to | Required args | Optional args |
|---|---|---|---|
| `new` | `copier copy` | `<dest>` | `--preset`, `--lint`, `--hook`, `--dry-run`, `+/-` flags |
| `update` | `copier update` | (none) | `[dest]` (default `.`), `--dry-run`, `+/-` flags, `--data` passthrough |

---

## Named Options

| Flag | Values | Default | Notes |
|---|---|---|---|
| `--preset` | `minimal`, `standard`, `full` | `standard` | Only meaningful on `new` |
| `--lint` | `strict`, `standard`, `relaxed` | (from preset) | Only passed if explicitly set |
| `--hook` | `pre-commit`, `lefthook`, `none` | `none` | Only passed if explicitly set |
| `--dry-run` | (flag) | off | Passes `--pretend` to copier |
| `--help` | (flag) | — | Show usage |

---

## Feature Flag Syntax

A single string of `+name` and `-name` tokens, parsed left-to-right.
`+name` sets the corresponding `has_*` variable to `true`.
`-name` sets it to `false`.

### Alias Map

| Short name | Copier variable |
|---|---|
| `cli` | `has_cli` |
| `core` | `has_core_library` |
| `config` | `has_config` |
| `jsonl` | `has_jsonl_logging` |
| `otel` | `has_opentelemetry` |
| `bench` | `has_benchmarks` |
| `gungraun` | `has_gungraun` |
| `site` | `has_site` |
| `community` | `has_community_files` |
| `claude` | `has_claude` |
| `claude-skills` | `has_claude_skills` |
| `claude-commands` | `has_claude_commands` |
| `claude-rules` | `has_claude_rules` |
| `yamlfmt` | `has_yamlfmt` |
| `yamllint` | `has_yamllint` |
| `editorconfig` | `has_editorconfig` |
| `env` | `has_env_files` |
| `agents-md` | `has_agents_md` |
| `just` | `has_just` |
| `gitattributes` | `has_gitattributes` |
| `github` | `has_github` |
| `security-md` | `has_security_md` |
| `issues` | `has_issue_templates` |
| `prs` | `has_pr_templates` |
| `md` | `has_md` |
| `md-strict` | `has_md_strict` |
| `skill-markdown` | `has_skill_markdown_authoring` |
| `skill-decisions` | `has_skill_capturing_decisions` |
| `skill-git` | `has_skill_using_git` |

Unknown aliases produce an error listing the bad name and all valid aliases.

---

## Generated Copier Command

### `new`

```bash
copier copy --trust --defaults \
  --data project_name=<basename of dest> \
  --data preset=<preset> \
  [--data lint_level=<lint>] \
  [--data hook_system=<hook>] \
  [--data has_*=true/false ...] \
  <template-dir> <dest>
```

- `--defaults` skips interactive prompts for anything not explicitly provided.
- `--trust` enables post-generation tasks (git init, etc.).
- Template source resolved relative to the script: `$(dirname "$0")/../template`.
- `project_name` derived from `basename <dest>`.

### `update`

```bash
copier update --trust \
  [--data has_*=true/false ...] \
  [dest]
```

- No `--defaults` (copier update doesn't use it the same way).
- Destination defaults to `.`.

---

## Error Handling

| Condition | Behavior |
|---|---|
| No args / unknown subcommand | Print usage, exit 1 |
| `new` without destination | Error: "destination path required" |
| Unknown feature alias | Error listing bad name + all valid aliases |
| `copier` not on PATH | Error: "copier not found. Install: pipx install copier" |
| Destination exists on `new` | Let copier handle it (it prompts for overwrite) |

---

## Help Output

```
Usage: claylo-rs <command> [options] [+feature-flags]

Commands:
  new <dest>       Create a new project (copier copy)
  update [dest]    Update an existing project (copier update)

Options:
  --preset <name>  minimal, standard, full (default: standard)
  --lint <level>   strict, standard, relaxed (default: from preset)
  --hook <system>  pre-commit, lefthook, none (default: none)
  --dry-run        Preview without writing files
  --help           Show this help

Feature flags (prefix with + to enable, - to disable):
  cli, core, config, jsonl, otel, bench, gungraun, site,
  community, claude, claude-skills, claude-commands, claude-rules,
  yamlfmt, yamllint, editorconfig, env, agents-md, just,
  gitattributes, github, security-md, issues, prs, md, md-strict,
  skill-markdown, skill-decisions, skill-git

Examples:
  claylo-rs new ./my-app
  claylo-rs new ./my-app --preset full +otel-site
  claylo-rs new ./my-app --preset minimal +core+config+bench
  claylo-rs update ./my-app +otel
  claylo-rs update . -site-community
```

---

## Implementation Notes

- Single bash file at `bin/claylo-rs`.
- `set -euo pipefail` for safety.
- Alias map as an associative array.
- Feature string parsed with a regex/loop splitting on `+` and `-` boundaries.
- The script must be executable (`chmod +x`).
