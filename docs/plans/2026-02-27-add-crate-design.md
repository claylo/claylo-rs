# Design: `scripts/add-crate`

Post-generation tool for adding new crates to an existing workspace.

## Problem

After generating a project with `copier copy`,
users need to add crates to their workspace —
a second binary, a shared library, a derive macro crate.
Today this means manually creating `Cargo.toml`, `src/`, and wiring up workspace members.
The script automates this while respecting project conventions.

## Decisions

- **Bash script** — matches `scripts/deps` pattern, zero dependencies, ships in every generated project.
- **Generic with conventions** — works with any Rust workspace. Detects claylo-rs projects via `.repo.yml` and applies conventions (workspace inheritance, `crates/` layout, standard deps).
- **Interactive with flag overrides** — prompts when invoked bare, flags skip prompts for scripting.
- **Always included** — not gated behind a `has_*` flag. Every generated project gets it.
- **No copier.yaml changes** — the script discovers conventions at runtime, not at generation time.

## Invocation

```bash
# Interactive (prompts for everything):
scripts/add-crate

# Flag-driven (skip prompts):
scripts/add-crate lib my-utils
scripts/add-crate bin my-daemon
scripts/add-crate internal my-macros --derive

# Via justfile:
just add-crate lib my-utils
```

## Crate Types

| Type | Creates | Use case |
|------|---------|----------|
| `lib` | `src/lib.rs` | Reusable library (utilities, domain logic, clients) |
| `bin` | `src/main.rs` + optional `src/lib.rs` | CLI binary or daemon |
| `internal` | `src/lib.rs`, optionally `proc-macro = true` | Derive macros, proto definitions, internal support |

## Interactive Prompts

When flags are not provided, the script prompts:

1. **Crate type?** — lib / bin / internal
2. **Crate name?** — validated: lowercase, hyphens allowed, no collisions
3. **Brief description?** — one line for `Cargo.toml` `description` field
4. **Common features?** — multi-select, varies by type (serde, tracing, async/tokio, clap)

Flags override any prompt they cover.

## Generated Output

### Library crate (`lib`)

```
crates/my-utils/
├── Cargo.toml
└── src/
    └── lib.rs
```

**Cargo.toml:**

```toml
[package]
name = "my-utils"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
license.workspace = true
description = "Utility library"
publish = false

[lints]
workspace = true

[dependencies]
```

**src/lib.rs:**

```rust
//! my-utils — Utility library

```

### Binary crate (`bin`)

Same structure with `src/main.rs` instead.
Uses `anyhow` for error handling in claylo-rs projects.
Includes the `run() -> Result` + `ExitCode` pattern.

### Internal crate (`internal`)

Same as `lib`.
With `--derive`, adds `[lib] proc-macro = true` to `Cargo.toml`.

## Convention Detection

### claylo-rs projects (`.repo.yml` exists)

- Places crate under `crates/`
- Uses workspace inheritance: `version.workspace = true`, `edition.workspace = true`, etc.
- Adds `[lints] workspace = true`
- Uses `thiserror` for lib error types
- Uses `anyhow` for bin error handling
- Reads edition and MSRV from workspace `Cargo.toml`

### Generic workspaces (no `.repo.yml`)

- Reads workspace `Cargo.toml` to discover member patterns
- Places crate where it fits the existing layout
- Uses inline `edition` and `rust-version` unless workspace keys exist
- Minimal boilerplate — no assumptions about error crates

## Workspace Integration

After generating files, the script:

1. **Checks auto-discovery** — if `members` includes a glob like `crates/*`, the new crate is already visible. No edit needed.
2. **Adds to members** — if the workspace uses explicit paths, appends the new crate.
3. **Runs `cargo check -p <name>`** — validates the new crate compiles.
4. **Prints next steps.**

**Example output:**

```
Created library crate 'my-utils' at crates/my-utils/
  ✓ Workspace auto-discovers crates/* — no Cargo.toml changes needed
  ✓ cargo check -p my-utils passed

Next steps:
  • Add dependencies: cargo add -p my-utils <dep>
  • Use from another crate: cargo add -p my-project --path crates/my-utils
```

## Validation

The script validates:

- Crate name uses lowercase alphanumeric characters and hyphens
- No leading hyphen, no Rust keywords
- No collision with existing workspace members
- No collision with common crates.io names that cause ambiguity (the `serde-test` problem)
- Workspace root exists (fail gracefully otherwise)

## Not In Scope

- Adding the new crate as a dependency of existing crates (use `cargo add --path`)
- Generating test files beyond the empty `src/` stub
- Feature flag scaffolding in the new crate
- CI/workflow modifications
- Copier.yaml changes

## Template Integration

**Template file:** `template/scripts/add-crate` (plain file, no `.jinja` suffix — conventions are discovered at runtime)

**Justfile recipe:**

```just
# Add a new crate to the workspace
add-crate *ARGS:
    scripts/add-crate {{ARGS}}
```

**Permissions:** Source file is `chmod +x`; copier preserves this.

**Always included:** Ships with every generated project regardless of preset or feature flags.
