# claylo-rs Project Instructions

## Project Overview

This is a **Copier template** for generating production-ready Rust CLI applications. The template supports multiple presets (minimal, standard, standard-otel, full) and optional features.

## Decision Guardrails

**STOP and ASK before:**

1. **Structural changes** - Moving files, splitting configs, changing directory layout, renaming established patterns. If you think "this would be cleaner if...", ask first.

2. **Adding copier.yaml variables** - Every variable in copier.yaml becomes a prompt shown to users generating projects. Ask yourself: "Would a user creating a new Rust CLI project need to answer this?" If the answer involves testing, CI, or template development, it doesn't belong in copier.yaml.

3. **"Clever" workarounds** - If the straightforward approach seems blocked and you're considering a creative alternative, stop. The creative alternative is probably wrong. Ask for guidance.

4. **Anything that feels like a shortcut** - Quick fixes that "work for now" tend to create cleanup work later. This is a template that will generate many projects - shortcuts compound.

**Template vs. Template Testing:**

- `copier.yaml` variables = what users see when generating projects
- `scripts/` = testing infrastructure for the template itself
- These are completely separate concerns. Test fixtures, CI helpers, and development tooling NEVER go in copier.yaml.

**The user perspective test:** Before adding any copier.yaml variable, ask: "If I were a developer running `copier copy gh:claylo/claylo-rs my-new-cli`, would I understand why I'm being asked this?"

## Emphasize Modularity

Rather than having multiple templates for different degrees of functionality, this template offers a modular approach. Users can choose from various presets and selectively enable features to tailor their project's requirements. When adding a new capability to the template, consider how it can be integrated into the existing modular structure, and modularized itself.

REMEMBER: you are a cool and crafty assistant! Together, we can create a modular and flexible template that meets the diverse needs of our users.

## Key Files and Directories

- `copier.yaml` - Copier configuration file. DO NOT MOVE INTO `template/`
- `template/` - The Copier template source (Jinja2 files)
- `test/` - Bats test suites and vendored test runner
- `scripts/` - Preset data files and helper scripts
- `docs/` - Project documentation and ADRs (`docs/decisions/`)
- `.claude/plans/` - Implementation roadmaps
- `.justfile` - Template development recipes (run `just` to list)
- `bin/claylo-rs` - Wrapper script for copier with friendly flags

If there are problems related to the location of the `copier.yaml` file, fix the problems
instead of just moving the file into `template/`.

## Testing

**IMPORTANT:** Always use `target/template-tests/` for test output, NOT `/tmp`.

### Running Tests

Use `just` commands — they invoke vendored bats automatically:

| Command | What it runs |
|---------|-------------|
| `just test` | All bats tests |
| `just test-fast` | Conditional file tests only (no cargo build) |
| `just test-presets` | Full preset build tests (slow) |
| `just test-file test/foo.bats` | Single test file |

For reduced output (saves context window tokens), use the agents formatter:

```bash
./test/bats/bin/bats -F "$PWD/test/formatters/agents.bash" test/*.bats
```

### Test Types

- **Conditional file tests** (`test/conditional_files.bats`): Fast — verify modular flags include/exclude files without cargo builds.
- **Preset tests** (`test/presets.bats`): Slow — full end-to-end with clippy + nextest for each preset.

When adding new modular flags, add a conditional file test first.

### Manual Copier Invocation

When running copier programmatically, use **both** `--trust` and `--defaults`:

```bash
copier copy --trust --defaults --data-file scripts/presets/standard.yml template target/template-tests/my-test
```

| Flag | Purpose |
|------|---------|
| `--trust` | Required for post-generation tasks (git init, hook install) |
| `--defaults` | Skips interactive prompts, uses default values from copier.yaml |
| `--data-file` | Overrides specific variables for the test scenario |

## Template Variables

Key Copier variables (see `copier.yaml` for full list):

**Project identity:**
- `project_name`, `owner`, `copyright_name`, `project_description`
- `edition` (default: 2024), `msrv` (default: 1.88.0), `pinned_dev_toolchain` (default: 1.93.0)
- `license`, `categories`

**Presets and levels:**
- `preset` - minimal, standard, full (sets defaults for feature flags)
- `lint_level` - strict (all + nursery), standard (all only)
- `hook_system` - pre-commit, lefthook, none

**Feature flags:**
- `has_cli`, `has_core_library`, `has_config`
- `has_jsonl_logging`, `has_opentelemetry`, `has_mcp_server`
- `has_benchmarks`, `has_gungraun`, `has_xtask`, `has_site`
- `has_community_files`, `has_github`, `has_security_md`, `has_issue_templates`, `has_pr_templates`

**Dotfiles and tooling:**
- `has_yamlfmt`, `has_yamllint`, `has_editorconfig`, `has_env_files`
- `has_agents_md`, `has_just`, `has_gitattributes`
- `has_md`, `has_md_strict`

**Claude Code config:**
- `has_claude`, `has_claude_skills`, `has_claude_commands`, `has_claude_rules`
- `has_skill_markdown_authoring`, `has_skill_capturing_decisions`, `has_skill_using_git`

**Computed (not user-facing):**
- `needs_tokio` — true when `has_opentelemetry` or `has_mcp_server`
- `has_pre_commit`, `has_lefthook` — derived from `hook_system`

**IMPORTANT:** Always run `just fmt` and `just lint` and correct any issues in `copier.yaml` before presenting a change to user.

## Conditional Directories

The template uses Copier's conditional directory pattern:
```
{{ "dirname" if condition else "__skip_dirname__" }}
```

Files/directories starting with `__skip_` are excluded from output.

## Jinja Escaping

When template files need Just's own `{{variable}}` syntax, use:
```jinja
{% raw %}{{variable}}{% endraw %}
```

## Development Workflow

1. Make changes to files in `template/`
2. Run `just test-fast` to verify conditional file inclusion
3. Run `just test-presets` when changes affect generated Rust code
4. Run `just fmt` and `just lint` if `copier.yaml` was modified

### Generated Project Commands

When verifying a generated project builds correctly:
- `cargo nextest run` for tests (NOT `cargo test`)
- `cargo clippy --all-targets --all-features -- -D warnings`
- `cargo fmt --all`

## Quality Bar

This project has a high quality bar. Every decision should be defensible to someone reviewing the code a year from now.

**Before making changes, review:**

- Does this change align with the existing architecture?
- Would this surprise someone familiar with the codebase?
- Am I adding complexity that could be avoided?
- Is this solving the user's actual problem, or a problem I invented?

**When in doubt:**

- Ask rather than assume
- Do less rather than more
- Match existing patterns rather than "improve" them
- If something feels like it needs explanation, it probably needs discussion first

**Red flags that should trigger a pause:**

- Adding new config files or directories
- Changing how existing variables work
- Adding dependencies to generated projects
- Anything touching copier.yaml structure
- "This would be easier if we just..." thoughts
