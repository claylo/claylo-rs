---
status: accepted
date: 2026-01-04
---

# Hierarchical Configuration Discovery

## Context and Problem Statement

CLI tools need configuration. Should the template include a configuration system, and if so, how sophisticated should it be? Simple tools might only need command-line flags, but enterprise applications often require layered configuration from multiple sources.

## Decision Drivers

* Enterprise applications frequently need swappable configuration files for different environments
* DRY principle: shared settings shouldn't be duplicated across config files
* User preferences should have a standard location (`~/.config/`)
* Project-specific settings should live with the project
* Configuration discovery should "just work" without explicit paths

## Considered Options

* No configuration system (flags only)
* Simple single-file configuration
* Hierarchical configuration with merging

## Decision Outcome

Chosen option: "Hierarchical configuration with merging", because enterprise-grade applications consistently need this capability, and including it from the start prevents painful retrofitting later.

### Consequences

* Good, because configs can be layered: user defaults + project overrides + environment-specific
* Good, because config files are discovered automatically by walking up the directory tree
* Good, because common patterns (XDG config directory, dotfile in project root) work out of the box
* Good, because the `config` crate handles format parsing and merging
* Neutral, because adds dependencies (`config`, `dirs`, `camino`)
* Bad, because more complex than some projects need

### Confirmation

The implementation is confirmed by:
- Tests demonstrating config file discovery from nested directories
- Tests showing proper merge precedence (explicit > project > user > defaults)
- Boundary marker (`.git`) prevents traversing beyond project root

## Pros and Cons of the Options

### No configuration system (flags only)

* Good, because zero additional complexity
* Good, because no dependencies for config handling
* Bad, because users must pass flags every time
* Bad, because no persistence of preferences
* Bad, because must be added later when needed

### Simple single-file configuration

* Good, because straightforward to understand
* Good, because minimal dependencies
* Bad, because no layering (can't have user defaults + project overrides)
* Bad, because users must specify config path explicitly
* Bad, because doesn't scale to enterprise needs

### Hierarchical configuration with merging

* Good, because handles all common configuration patterns
* Good, because automatic discovery reduces user friction
* Good, because merging allows DRY configuration
* Neutral, because requires understanding precedence rules
* Bad, because adds complexity and dependencies

## More Information

The configuration system uses:
- `config` crate for parsing and merging
- `dirs` crate for XDG directory lookup
- `camino` for UTF-8 path handling
- `serde` for deserialization

See `crates/{app}-core/src/config.rs` in the generated project for implementation.

> **Note**: `{app}` refers to your project name (e.g., `myproject-core/src/config.rs`).
