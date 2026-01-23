# Independent Crate Releases

This document explains how to switch from global versioning to independent crate versioning, and how to work with independent versions.

## Background

By default, this template uses **global versioning**: all crates in the workspace share a single version number defined in the root `Cargo.toml`. This is simpler to manage but means every release bumps all crates, even if only one changed.

**Independent versioning** allows each crate to have its own version and release cycle. This is useful when:

- Your core library has different consumers than your CLI
- You want to publish patch releases to just one crate
- Crates evolve at different rates

## Switching from Global to Independent Versioning

If you generated the template with global versioning and want to switch:

### 1. Update crate Cargo.toml files

In each crate's `Cargo.toml`, change from workspace-inherited to explicit version:

```toml
# Before (global versioning)
[package]
name = "my-project-core"
version.workspace = true

# After (independent versioning)
[package]
name = "my-project-core"
version = "0.1.0"
```

Do this for all publishable crates (not xtask, which has `publish = false`).

### 2. Update cog.toml

Replace the version tag settings:

```toml
# Before (global versioning)
generate_mono_repository_global_tag = true
generate_mono_repository_package_tags = false

# After (independent versioning)
generate_mono_repository_global_tag = false
generate_mono_repository_package_tags = true
```

Replace bump hooks with package-specific hooks:

```toml
# Before (global versioning)
pre_bump_hooks = [
  "echo 'bumping from {{latest}} to {{version}}'",
  "cargo set-version {{version}}",
  "cargo check --release",
  "git add :/Cargo.lock"
]

# After (independent versioning)
pre_package_bump_hooks = [
  "echo 'bumping {{package}} to {{package_version}}'",
  "cargo set-version --package {{package}} {{package_version}}",
  "cargo check --release",
  "git add :/Cargo.lock"
]
```

### 3. Update inter-crate dependencies

When crates depend on each other, you may need to update version requirements:

```toml
[dependencies]
# Pin to compatible versions
my-project-core = { version = "0.1", path = "../my-project-core" }
```

## Working with Independent Versions

### Bumping a specific package

```bash
# Bump based on commits touching that package
cog bump --package my-project-core --auto

# Or specify the bump type
cog bump --package my-project-core --minor
```

### Tag format

With independent versioning, tags include the package name:

- Global: `v1.2.3`
- Independent: `my-project-core-v1.2.3`

### Changelogs

Each package can have its own changelog. Configure in `cog.toml`:

```toml
[packages.my-project-core]
path = "crates/my-project-core"
changelog_path = "crates/my-project-core/CHANGELOG.md"
```

### CI/CD considerations

With independent versioning, you'll need to update your release workflow to:

1. Detect which package was tagged
2. Build/publish only that package
3. Create package-specific GitHub releases

Example tag detection in GitHub Actions:

```yaml
- name: Determine package from tag
  id: package
  run: |
    TAG="${{ github.ref_name }}"
    if [[ "$TAG" == *"-v"* ]]; then
      PACKAGE="${TAG%-v*}"
      VERSION="${TAG##*-v}"
    else
      PACKAGE=""
      VERSION="${TAG#v}"
    fi
    echo "package=$PACKAGE" >> $GITHUB_OUTPUT
    echo "version=$VERSION" >> $GITHUB_OUTPUT
```

## Tradeoffs

| Aspect | Global | Independent |
|--------|--------|-------------|
| Simplicity | Simpler | More complex |
| Release granularity | All-or-nothing | Per-crate |
| Dependency management | Automatic | Manual version sync |
| Changelog | Single | Per-package |
| CI/CD | Simpler | Needs package detection |

## When to use each

**Use global versioning when:**
- Crates are tightly coupled
- You always release together
- You want simpler tooling

**Use independent versioning when:**
- Crates have different audiences
- Core library is stable but CLI changes often
- You need to publish hotfixes to specific crates

## See also

- [Cocogitto Monorepo Guide](https://docs.cocogitto.io/guide/monorepo.html)
- [Cargo Workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html)
