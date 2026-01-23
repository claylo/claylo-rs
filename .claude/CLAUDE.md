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

- `template/` - The Copier template source (Jinja2 files)
- `scripts/` - Test scripts and preset configurations
- `docs/` - Project documentation
- `.claude/plans/` - Implementation roadmaps
- `copier.yaml` - Copier configuration file. DO NOT MOVE INTO `template/`

If there are problems related to the location of the `copier.yaml` file, fix the problems
instead of just moving the file into `template/`.

## Testing Template Generation

**IMPORTANT:** Always use `target/template-tests/` for test output, NOT `/tmp`.

```bash
# Correct
copier copy --trust template target/template-tests/test-project --data project_name=test ...

# WRONG - do not use /tmp
copier copy --trust template /tmp/test-project ...
```

The test script `scripts/test-template.sh` uses `target/template-tests/` automatically.

### Copier Flag Usage

When running copier programmatically (e.g., in test scripts), use **both** `--trust` and `--defaults`:

```bash
copier copy --trust --defaults --data-file test-data.yml template output-dir
```

| Flag | Purpose |
|------|---------|
| `--trust` | Required for post-generation tasks (git init, hook install) |
| `--defaults` | Skips interactive prompts, uses default values from copier.yaml |
| `--data-file` | Overrides specific variables for the test scenario |

This combination allows fast, non-interactive testing of conditional file inclusion without needing to specify every possible variable in the data file.

### Test Structure

The test script runs two types of tests:

1. **Conditional file tests** (fast, no cargo build): Verify modular flags correctly include/exclude files. These use minimal data files with only the flags being tested.

2. **Preset tests** (full build + verification): Test each preset end-to-end with `cargo clippy`, `cargo nextest run`, and feature verification (JSONL logging, config discovery, etc.)

When adding new modular flags, add a conditional file test to verify the flag works without requiring a full cargo build cycle.

## Template Variables

Key Copier variables (see `copier.yaml`):
- `project_name` - Rust project name (lowercase, hyphens)
- `preset` - minimal, standard, full
- `has_cli`, `has_core_library`, `has_config`
- `has_jsonl_logging`, `has_opentelemetry`
- `has_benchmarks`, `has_xtask`
- `has_claude`, `has_claude_skills`, `has_claude_commands`, `has_claude_rules`

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

## Running Cargo Commands

Use the rust-mcp-server tools or direct commands:
- `cargo nextest run` for tests (NOT `cargo test`)
- `cargo clippy --all-targets --all-features -- -D warnings`
- `cargo fmt --all`

## Development Workflow

1. Make changes to files in `template/`
2. Test with: `scripts/test-template.sh` or manual copier copy
3. Verify generated project builds: `cd target/template-tests/test-* && cargo check`

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
