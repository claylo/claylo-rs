# Adding Crates to Your Workspace

Generated projects with `has_cli=true` (minimal, standard, full presets) include
`scripts/add-crate`, a tool for adding new crates to your workspace
without manual Cargo.toml wiring.

> The library preset generates a flat crate (no workspace), so `add-crate` is not included.

## Quick Start

```bash
# Interactive — prompts for everything
just add-crate

# Direct — skip prompts
just add-crate lib my-utils
just add-crate bin my-daemon
just add-crate internal my-macros --derive
```

## Crate Types

| Type | Creates | Use case |
|------|---------|----------|
| `lib` | `src/lib.rs` | Reusable library (utilities, domain logic, API clients) |
| `bin` | `src/main.rs` | CLI binary or daemon |
| `internal` | `src/lib.rs` | Workspace-internal support (macros, proto, shared types) |

## Options

| Option | Description |
|--------|-------------|
| `-d`, `--description TEXT` | Crate description (skips prompt) |
| `--derive` | Set up as proc-macro crate (internal type only) |
| `-h`, `--help` | Show usage help |

## What Gets Generated

For `just add-crate lib my-utils -d "Shared utilities"`:

```
crates/my-utils/
├── Cargo.toml
└── src/
    └── lib.rs
```

The generated `Cargo.toml` uses workspace inheritance:

```toml
[package]
name = "my-utils"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
license.workspace = true
description = "Shared utilities"
publish = false

[dependencies]
thiserror = "2.0"

[lints]
workspace = true
```

Binary crates get `anyhow` and `clap` instead of `thiserror`,
plus a `main.rs` with the `run() -> Result` / `ExitCode` pattern.

## Convention Detection

The script detects whether it's running in a claylo-rs project
by checking for `.repo.yml` (the copier answers file).

**In claylo-rs projects:**

- Places new crates under `crates/`
- Uses workspace inheritance (`version.workspace = true`, etc.)
- Adds `[lints] workspace = true`
- Includes conventional dependencies (`thiserror` for libs, `anyhow` + `clap` for bins)

**In other Rust workspaces:**

- Reads workspace `Cargo.toml` to discover the member layout
- Uses inline edition and MSRV if workspace keys aren't available
- Minimal boilerplate — no assumptions about error handling crates

## Workspace Integration

The script checks whether your workspace auto-discovers new crates.
If `members` includes a glob like `"crates/*"`,
no `Cargo.toml` changes are needed.
Otherwise, the script adds the new crate to the members list.

After generating files,
the script runs `cargo check -p <name>` to verify everything compiles.

## After Adding a Crate

```bash
# Add dependencies
cargo add -p my-utils serde

# Use from another crate in the workspace
cargo add -p my-project --path crates/my-utils
```
