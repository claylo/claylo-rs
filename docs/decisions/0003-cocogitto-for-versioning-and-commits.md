---
status: superseded
date: 2026-01-04
superseded_by: Release tooling moved to separate template (2026-01-27)
---

# Cocogitto for Versioning and Commits

## Context and Problem Statement

Rust projects need tooling for version management and release automation. Several tools exist: cargo-release, release-plz, cocogitto (cog), and manual processes. Which should the template use?

## Decision Drivers

* Conventional Commits enforcement for consistent commit messages
* Automatic changelog generation from commit history
* Git hooks management (commit-msg, pre-commit, pre-push)
* Monorepo awareness for workspace projects
* Safety: avoid accidental releases to crates.io
* Quality documentation for learning and troubleshooting

## Considered Options

* Manual versioning with scripts
* cargo-release
* release-plz
* Cocogitto (cog)

## Decision Outcome

Chosen option: "Cocogitto (cog)", because it bundles git hooks management with version bumping, has excellent monorepo support, superior documentation, and doesn't auto-publish to crates.io without explicit action.

### Consequences

* Good, because git hooks are defined in `cog.toml` and installed with `cog install-hook`
* Good, because Conventional Commits are enforced automatically
* Good, because changelogs are generated from commit history
* Good, because monorepo support works with workspace-inherited versions
* Good, because documentation is comprehensive and well-organized
* Neutral, because requires learning cog's configuration format
* Bad, because another tool to install (`cargo install cocogitto`)

### Confirmation

The setup is confirmed by:
- `cog check` validates all commits follow conventional format
- `cog bump --auto` calculates version from commit types
- Git hooks in `cog.toml` are installed and functional

## Pros and Cons of the Options

### Manual versioning with scripts

* Good, because full control
* Good, because no additional tools
* Bad, because error-prone
* Bad, because no commit validation
* Bad, because manual changelog maintenance

### cargo-release

* Good, because well-established
* Good, because handles crates.io publishing
* Bad, because no commit message validation
* Bad, because no built-in git hooks
* Neutral, because focused on single-crate workflows

### release-plz

* Good, because automates PR-based releases
* Good, because integrates with CI
* Bad, because auto-published to crates.io in early experiments (footgun)
* Bad, because more opinionated workflow
* Neutral, because requires GitHub App or token setup

### Cocogitto (cog)

* Good, because bundles hooks + versioning + changelog
* Good, because excellent monorepo support
* Good, because comprehensive documentation
* Good, because explicit control over publishing
* Neutral, because configuration in `cog.toml` to learn
* Bad, because less common than alternatives

## Conditional Adoption

This decision is **optional** via the `hook_system` template variable.

**Available choices:**

| Value | Description |
|-------|-------------|
| `cog` | Cocogitto with conventional commits (default for standard/full) |
| `pre-commit` | pre-commit.com framework |
| `lefthook` | Fast polyglot hook runner |
| `none` | No git hooks (default for minimal preset) |

When `hook_system != 'cog'`:
- `cog.toml` is not generated
- `just bootstrap` installs hooks for the chosen system (or skips if `none`)
- `bump.yml` workflow is not included
- Users manage versioning with their preferred tooling

## More Information

Key cog commands:
- `cog check` - Verify commits follow Conventional Commits
- `cog bump --auto` - Bump version based on commit types
- `cog changelog` - Generate/update CHANGELOG.md
- `cog install-hook --all` - Install git hooks

See [Cocogitto documentation](https://docs.cocogitto.io/) for details.
