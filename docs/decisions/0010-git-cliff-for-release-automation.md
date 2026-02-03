---
status: accepted
date: 2026-02-01
supersedes: 0003-cocogitto-for-versioning-and-commits
---

# Git-cliff for Release Automation

## Context and Problem Statement

Release automation was initially removed from claylo-rs (2026-01-27) with the rationale that release workflows are orthogonal to project structure. However, having *some* release scaffolding is valuable—the question is how much opinion to encode.

The previous approach (ADR-0003) used Cocogitto, which bundles commit validation, version bumping, changelog generation, and git hooks into one tool. This proved to be "a LOT" when combined with cargo-dist and variant tooling options.

## Decision Drivers

* Simplicity: release tooling should be easy to understand and modify
* Transparency: users should see what's happening, not magic
* Optionality: easy to turn off entirely if users prefer their own stack
* Conventional Commits: still valuable for changelog generation
* No lock-in: avoid tools that take over the release process

## Considered Options

* No release automation (status quo after 2026-01-27 removal)
* Cocogitto (previous choice, ADR-0003)
* cargo-dist for binary releases
* git-cliff for changelog generation only
* git-cliff + transparent GitHub Actions

## Decision Outcome

Chosen option: "git-cliff + transparent GitHub Actions", because it provides useful release scaffolding while keeping everything visible and modifiable.

### What's Included

When `has_releases=true` (default for `full` preset only):

| File | Purpose |
|------|---------|
| `cliff.toml` | git-cliff changelog configuration |
| `.github/workflows/release.yml` | Automatic releases on merge to main |
| `.github/workflows/cd.yml` | Cross-platform builds and publishing |
| `docs/releases.md` | Project-specific release documentation |

Plus Justfile recipes: `changelog`, `changelog-preview`, `bump`, `release`.

### Why git-cliff over Cocogitto

| Aspect | Cocogitto | git-cliff |
|--------|-----------|-----------|
| Scope | Commits + versions + changelog + hooks | Changelog only |
| Complexity | High (many features) | Low (one job, done well) |
| Version bumping | Built-in `cog bump` | External (scripts, CI) |
| Hook management | Built-in | Not included |
| Customization | TOML config | Tera templates (powerful) |
| Maintenance | Learn cog's model | Standard tools |

git-cliff does one thing—generate changelogs from conventional commits—and does it well. Version bumping is handled by simple shell scripts or CI logic, which is easier to debug and customize.

### Why Not cargo-dist

cargo-dist is comprehensive but opaque:

1. **Generates complex workflows** that are hard to modify
2. **Opinionated about artifacts** (installers, formats, attestation)
3. **Expects to own the release process**

This template takes a hands-on approach instead:

1. **Transparent**: All workflow logic is visible in the YAML
2. **Customizable**: Easy to add/remove targets or steps
3. **Debuggable**: Standard GitHub Actions patterns
4. **Flexible**: Mix manual and automatic releases

Users who want cargo-dist can run `cargo dist init` on top of a generated project.

### Consequences

* Good, because changelogs are generated automatically from conventional commits
* Good, because all release logic is visible and modifiable
* Good, because easy to disable (`-releases` flag or delete files)
* Good, because no new CLI tools required (git-cliff runs in CI)
* Neutral, because version bumping requires understanding the scripts
* Bad, because less "batteries included" than Cocogitto for local workflows

### Confirmation

The implementation is confirmed by:
- `just changelog` generates CHANGELOG.md from commit history
- `just release v1.2.3` creates a tagged release with validation
- CI workflows build cross-platform binaries on tag push
- All publishing is opt-in via repository variables

## Runtime Configuration

Publishing targets are controlled by **repository variables**, not template flags:

| Variable | Purpose |
|----------|---------|
| `AUTO_RELEASE_ENABLED` | Enable automatic releases on merge |
| `CRATES_IO_ENABLED` | Publish to crates.io |
| `HOMEBREW_ENABLED` | Update Homebrew formula |
| `DEB_ENABLED` | Build .deb packages |
| `NPM_ENABLED` | Publish to npm |

This allows enabling/disabling features after project generation without re-running copier.

## More Information

See [docs/releases.md](../releases.md) for the full release workflow documentation.

Key differences from ADR-0003:
- No commit validation hooks (use pre-commit or lefthook if desired)
- No `cog bump --auto` (version calculated in CI or via `just bump`)
- Changelog templates use Tera instead of Cocogitto's format
- All complexity is visible in workflow files, not hidden in tool behavior
