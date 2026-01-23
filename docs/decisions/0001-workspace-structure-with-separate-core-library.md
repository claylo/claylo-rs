---
status: accepted
date: 2026-01-04
---

# Workspace Structure with Separate Core Library

## Context and Problem Statement

When creating a new CLI tool, should the project be structured as a single crate or as a workspace with multiple crates? Many simple CLIs are single-crate projects, but this template needs to serve as a foundation for tools that may grow in scope.

## Decision Drivers

* Tools often need to be embedded in desktop apps, web applications, or used as libraries
* "API First" philosophy: the CLI should be a thin interface over a reusable library
* Testability: core logic should be testable without CLI argument parsing
* Separation of concerns: error handling patterns differ between libraries and binaries
* Future extensibility without major refactoring

## Considered Options

* Single crate with everything
* Workspace with binary + core library
* Workspace with binary + multiple feature-specific libraries

## Decision Outcome

Chosen option: "Workspace with binary + core library", because it enforces API-first design from the start while keeping complexity manageable.

### Consequences

* Good, because the core library can be reused in other contexts (desktop apps, web services, other CLIs)
* Good, because it enforces clean separation between interface and implementation
* Good, because library code uses `thiserror` for typed errors while the binary uses `anyhow` for flexibility
* Good, because core logic can be unit tested without invoking the CLI
* Neutral, because it adds some initial structure that may seem like overkill for trivial tools
* Bad, because dependency changes may require updates in multiple Cargo.toml files

### Confirmation

The structure is confirmed by:
- Core library exports public types that the CLI consumes
- Tests in `-core` don't depend on CLI argument parsing
- The binary crate is a thin wrapper that delegates to core functionality

## Pros and Cons of the Options

### Single crate with everything

* Good, because simpler initial setup
* Good, because fewer files to manage
* Bad, because mixing CLI concerns with library logic
* Bad, because harder to reuse in other contexts
* Bad, because harder to test core logic in isolation

### Workspace with binary + core library

* Good, because clean separation of concerns
* Good, because core is reusable
* Good, because appropriate error handling patterns for each context
* Neutral, because slightly more initial complexity
* Bad, because version coordination between crates

### Workspace with binary + multiple feature-specific libraries

* Good, because maximum modularity
* Bad, because premature optimization for most projects
* Bad, because significant coordination overhead
