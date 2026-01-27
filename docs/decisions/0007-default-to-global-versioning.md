---
status: superseded
date: 2026-01-04
superseded_by: Release tooling moved to separate template (2026-01-27). Workspace version inheritance is now always used.
---

# Default to Global Versioning

## Context and Problem Statement

In a Cargo workspace with multiple crates, should each crate have its own version (independent versioning) or should all crates share a single version (global versioning)? This affects release workflows, changelogs, and dependency management.

## Decision Drivers

* Simplicity of release process
* Flexibility for different crate lifecycles
* Coordination overhead between crate versions
* Tooling complexity (cog, cargo-dist, CI/CD)
* Precedent from major projects

## Considered Options

* Global versioning (all crates share one version)
* Independent versioning (each crate has own version)
* Hybrid (some shared, some independent)

## Decision Outcome

Chosen option: "Global versioning" as the default, with an option at template generation time to choose independent versioning. This follows the pattern used by Apache Arrow/DataFusion and keeps the default workflow simple.

### Consequences

* Good, because simpler release process—one version bump affects all crates
* Good, because changelog is unified
* Good, because follows proven patterns (Arrow/DataFusion)
* Good, because users can opt into independent versioning if needed
* Neutral, because a patch to `-core` also bumps the CLI version
* Bad, because less granular control over individual crate releases

### Confirmation

The default is confirmed by:
- Workspace `Cargo.toml` defines `version` in `[workspace.package]`
- Crate `Cargo.toml` files use `version.workspace = true`
- `cog.toml` uses `generate_mono_repository_global_tag = true`

## Pros and Cons of the Options

### Global versioning

* Good, because one version to track
* Good, because simpler changelog
* Good, because simpler CI/CD
* Good, because no cross-crate version coordination
* Bad, because can't release just one crate
* Bad, because version numbers may increase without changes to some crates

### Independent versioning

* Good, because granular release control
* Good, because version numbers reflect actual changes
* Bad, because must coordinate inter-crate dependencies
* Bad, because more complex tooling setup
* Bad, because multiple changelogs to maintain

### Hybrid approach

* Good, because flexibility where needed
* Bad, because most complex to understand
* Bad, because inconsistent mental model
* Bad, because tooling may not handle well

## More Information

The versioning strategy is selected at template generation time via the `versioning` placeholder:

```
cargo generate --name my-project gh:owner/rust-template
# Prompts for: Versioning strategy? [global/independent]
```

To switch from global to independent versioning after generation, see `docs/independent-crate-releases.md`.

With global versioning:
- `cog bump --auto` bumps all crates together
- Tags are `v1.2.3`
- Single `CHANGELOG.md` at repository root

With independent versioning:
- `cog bump --package foo --auto` bumps specific crate
- Tags are `foo-v1.2.3`
- Per-package changelogs possible
