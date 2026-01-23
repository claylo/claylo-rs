---
status: accepted
date: 2026-01-04
---

# xtask Pattern for Build Automation

## Context and Problem Statement

Projects need build automation beyond what `cargo build` provides: generating man pages, shell completions, running complex test scenarios, etc. How should these tasks be implemented?

## Decision Drivers

* Some tasks require introspection of Rust code (e.g., clap's command structure)
* Shell scripts are hard to maintain and not cross-platform
* Justfile recipes are good for simple commands but limited for complex logic
* Build tasks should be version-controlled and reproducible
* Tasks should integrate with the Rust toolchain

## Considered Options

* Shell scripts
* Justfile recipes only
* Build scripts (build.rs)
* xtask pattern

## Decision Outcome

Chosen option: "xtask pattern", because it enables Rust-native build automation with full access to the crate's types and structures, which is essential for generating man pages and shell completions from clap definitions.

### Consequences

* Good, because man pages are generated directly from clap's `Command` structure
* Good, because shell completions use `clap_complete` with the actual CLI definition
* Good, because complex logic is written in Rust, not shell
* Good, because cross-platform by default
* Good, because tasks can depend on and import from other workspace crates
* Neutral, because adds another crate to the workspace
* Bad, because slightly more setup than shell scripts

### Confirmation

The pattern is confirmed by:
- `cargo xtask man` generates accurate man pages
- `cargo xtask completions` produces working shell completions
- Both tasks use the actual CLI structure, not duplicated definitions

## Pros and Cons of the Options

### Shell scripts

* Good, because familiar to most developers
* Good, because no compilation needed
* Bad, because not cross-platform
* Bad, because no access to Rust types
* Bad, because harder to maintain complex logic

### Justfile recipes only

* Good, because simple and declarative
* Good, because cross-platform via just
* Bad, because limited to shell commands
* Bad, because no introspection capability
* Bad, because complex logic becomes unwieldy

### Build scripts (build.rs)

* Good, because native Cargo integration
* Good, because runs automatically on build
* Bad, because meant for compile-time code generation, not tasks
* Bad, because awkward for on-demand tasks
* Bad, because can't easily be run independently

### xtask pattern

* Good, because full Rust capabilities
* Good, because access to workspace crates
* Good, because cross-platform
* Good, because version-controlled
* Neutral, because requires workspace member
* Bad, because adds compilation overhead for tasks

## More Information

The xtask crate:
- Lives in `xtask/` at the workspace root
- Has `publish = false` (internal tool only)
- Depends on the main crate for CLI introspection
- Invoked via `cargo xtask <command>`

Current xtask commands:
- `cargo xtask man` - Generate man pages to `dist/share/man/man1/`
- `cargo xtask completions` - Generate shell completions to `dist/share/completions/`

See [cargo-xtask](https://github.com/matklad/cargo-xtask) for pattern documentation.
