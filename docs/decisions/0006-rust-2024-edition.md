---
status: accepted
date: 2026-01-04
---

# Rust 2024 Edition

## Context and Problem Statement

Rust editions allow the language to evolve while maintaining backward compatibility. The 2024 edition was stabilized in Rust 1.85 (February 2025). Should the template target the latest edition or maintain broader compatibility with 2021?

## Decision Drivers

* Language improvements in 2024 edition (e.g., improved async, new prelude items)
* Ecosystem adoption of 2024 edition
* Developer machine compatibility
* CI/CD tooling availability
* Following established projects' lead

## Considered Options

* Rust 2021 edition with lower MSRV
* Rust 2024 edition with MSRV 1.85
* Rust 2024 edition with MSRV 1.88

## Decision Outcome

Chosen option: "Rust 2024 edition with MSRV 1.88", because it's now 2026, the edition is well-established, and major projects like Apache Arrow/DataFusion have settled on 1.88 as a reasonable MSRV.

### Consequences

* Good, because access to all 2024 edition improvements
* Good, because forward-looking—new code won't need migration
* Good, because aligns with major ecosystem projects
* Neutral, because most developers have recent Rust versions
* Bad, because users with older Rust versions cannot build without upgrading

### Confirmation

The choice is confirmed by:
- All dependencies are compatible with Rust 1.88
- CI tests pass on the specified MSRV
- No edition-specific issues in the codebase

## Pros and Cons of the Options

### Rust 2021 edition with lower MSRV

* Good, because maximum compatibility
* Good, because users with older Rust can build
* Bad, because missing 2024 edition features
* Bad, because will need edition migration eventually
* Bad, because not forward-looking for new projects

### Rust 2024 edition with MSRV 1.85

* Good, because minimum version for 2024 edition
* Good, because access to all 2024 features
* Neutral, because 1.85 is relatively recent
* Bad, because some edge dependencies may not work

### Rust 2024 edition with MSRV 1.88

* Good, because proven stable by major projects (Arrow/DataFusion)
* Good, because access to all 2024 features
* Good, because buffer for any 1.85-specific issues
* Neutral, because requires slightly newer Rust than minimum
* Bad, because excludes users on older Rust versions

## More Information

MSRV is configurable at template generation time via the `msrv` placeholder in `cargo-generate.toml`. Users can specify a different MSRV if needed.

Key 2024 edition changes:
- Prelude includes `Future` and `IntoFuture`
- Improved RPIT (return position impl trait) lifetime capture
- `unsafe_op_in_unsafe_fn` lint is warn by default
- Various smaller improvements

See [Rust Edition Guide](https://doc.rust-lang.org/edition-guide/rust-2024/) for full details.
