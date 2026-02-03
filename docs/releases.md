# Release Automation

This template includes optional release automation using [git-cliff](https://git-cliff.org/) for changelog generation and semantic versioning, with a hands-on approach inspired by the git-cliff project's own release workflow.

## Feature Flag

| Variable | Default | Description |
|----------|---------|-------------|
| `has_releases` | `true` (full preset only) | Enable release automation |

Enable with the wrapper:

```bash
claylo-rs new ./my-app --preset full
# or
claylo-rs new ./my-app +releases
```

## What Gets Generated

When `has_releases` is enabled:

| File | Purpose |
|------|---------|
| `cliff.toml` | git-cliff changelog configuration |
| `.github/workflows/cd.yml` | Cross-platform builds and publishing |
| `.github/workflows/release.yml` | Automatic releases on merge to main |
| `docs/releases.md` | Project-specific release documentation |

Plus Justfile recipes for manual release management.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Release Flow                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Conventional Commits ──► git-cliff ──► Version + Changelog     │
│                                                                  │
│  ┌──────────────┐         ┌──────────────┐                      │
│  │ Manual Mode  │         │  Auto Mode   │                      │
│  │              │         │              │                      │
│  │ just bump    │         │ release.yml  │                      │
│  │ just release │         │ on: push     │                      │
│  │              │         │ to: main     │                      │
│  └──────┬───────┘         └──────┬───────┘                      │
│         │                        │                               │
│         └────────┬───────────────┘                               │
│                  ▼                                               │
│           Create git tag                                         │
│           (v1.2.3)                                               │
│                  │                                               │
│                  ▼                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                      cd.yml                                │  │
│  │  on: push tags: v*.*.*                                     │  │
│  │                                                            │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │  │
│  │  │ Changelog   │  │ Binaries    │  │ Packages    │        │  │
│  │  │ (git-cliff) │  │ (8 targets) │  │ (optional)  │        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │  │
│  │                          │                │                │  │
│  │                          ▼                ▼                │  │
│  │                   GitHub Release    crates.io / npm /     │  │
│  │                   + artifacts       brew / deb / rpm      │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## CD Workflow (cd.yml)

### Build Matrix

Cross-compilation for 8 targets:

| Platform | Targets |
|----------|---------|
| Linux | x86_64-gnu, x86_64-musl, aarch64-gnu, aarch64-musl |
| macOS | x86_64-apple-darwin, aarch64-apple-darwin |
| Windows | x86_64-pc-windows-msvc, aarch64-pc-windows-msvc |

### Build Features

- **cargo-auditable**: Embeds dependency info for vulnerability scanning
- **cargo-cyclonedx**: Generates SBOM (when `SBOM_ENABLED=true`)
- **GPG signing**: Signs tarballs (when `GPG_SIGNING_ENABLED=true`)
- **SHA256 checksums**: Generated for all tarballs

### Optional Publishing

All publishing is controlled by **repository variables**, not template flags. This allows enabling/disabling after project generation without re-running copier.

| Variable | Purpose | Required Secrets |
|----------|---------|------------------|
| `CRATES_IO_ENABLED` | Publish to crates.io | `CARGO_TOKEN` |
| `HOMEBREW_ENABLED` | Update Homebrew formula | `HOMEBREW_COMMITTER_TOKEN` |
| `DEB_ENABLED` | Build .deb packages | — |
| `RPM_ENABLED` | Build .rpm packages | — |
| `NPM_ENABLED` | Publish to npm | `NPM_TOKEN` |
| `SBOM_ENABLED` | Generate CycloneDX SBOM | — |
| `GPG_SIGNING_ENABLED` | Sign release artifacts | `GPG_RELEASE_KEY`, `GPG_PASSPHRASE` |

Set variables with:

```bash
gh variable set CRATES_IO_ENABLED --body "true"
gh variable set DEB_ENABLED --body "true"
```

### Setting Up crates.io Publishing

1. Create an API token at [crates.io/settings/tokens](https://crates.io/settings/tokens)
2. Set the secret:

```bash
gh secret set CARGO_TOKEN
```

### Setting Up Homebrew Distribution

1. Create a tap repository: `homebrew-tap` (e.g., `yourname/homebrew-tap`)
2. Create a Personal Access Token with `repo` scope for the tap repository
3. Set the secret:

```bash
gh secret set HOMEBREW_COMMITTER_TOKEN
```

4. Create an initial formula in your tap — see the generated `docs/releases.md` for a complete template

After your first release, `mislav/bump-homebrew-formula-action` updates the version and SHA256 automatically.

### Setting Up Debian Package Distribution

[cargo-deb](https://github.com/kornelski/cargo-deb) builds `.deb` packages from Cargo metadata.

Add to `Cargo.toml`:

```toml
[package.metadata.deb]
maintainer = "Your Name <email@example.com>"
copyright = "Your Name"
license-file = ["LICENSE-MIT", "4"]
extended-description = "Your project description"
section = "utility"
priority = "optional"
assets = [
    # Binary
    ["target/release/your-app", "usr/bin/", "755"],
    # Man pages (if using xtask)
    ["target/dist/share/man/man1/*", "usr/share/man/man1/", "644"],
    # Shell completions
    ["target/dist/share/completions/your-app.bash", "usr/share/bash-completion/completions/your-app", "644"],
    ["target/dist/share/completions/_your-app", "usr/share/zsh/vendor-completions/", "644"],
    ["target/dist/share/completions/your-app.fish", "usr/share/fish/vendor_completions.d/", "644"],
]
```

### Setting Up RPM Package Distribution

[cargo-generate-rpm](https://github.com/cat-in-136/cargo-generate-rpm) builds `.rpm` packages from Cargo metadata.

Add to `Cargo.toml`:

```toml
[package.metadata.generate-rpm]
assets = [
    { source = "target/release/your-app", dest = "/usr/bin/your-app", mode = "755" },
    { source = "target/dist/share/man/man1/*", dest = "/usr/share/man/man1/", mode = "644", doc = true },
    { source = "target/dist/share/completions/your-app.bash", dest = "/usr/share/bash-completion/completions/your-app", mode = "644" },
    { source = "target/dist/share/completions/_your-app", dest = "/usr/share/zsh/site-functions/_your-app", mode = "644" },
    { source = "target/dist/share/completions/your-app.fish", dest = "/usr/share/fish/vendor_completions.d/your-app.fish", mode = "644" },
]

[package.metadata.generate-rpm.requires]
# Add runtime dependencies here if needed
# glibc = ">= 2.17"
```

### Setting Up npm Distribution

npm distribution uses the [Sentry multi-package strategy](https://sentry.engineering/blog/publishing-binaries-on-npm): platform-specific packages with a wrapper that handles binary resolution.

#### Package Structure

```
npm/
├── your-app/                      # Main wrapper package
│   ├── package.json
│   ├── index.js                   # Binary resolution
│   ├── cli.js                     # CLI entry point
│   └── install.js                 # Postinstall fallback
└── platforms/
    ├── your-app-darwin-arm64/
    │   ├── package.json
    │   └── bin/your-app
    ├── your-app-darwin-x64/
    ├── your-app-linux-arm64/
    ├── your-app-linux-x64/
    ├── your-app-win32-arm64/
    └── your-app-win32-x64/
```

#### Platform Package (`package.json`)

```json
{
  "name": "@yourscope/your-app-linux-x64",
  "version": "0.1.0",
  "os": ["linux"],
  "cpu": ["x64"],
  "files": ["bin/"]
}
```

The `os` and `cpu` fields cause npm to skip incompatible packages automatically.

#### Main Wrapper Package

```json
{
  "name": "@yourscope/your-app",
  "bin": { "your-app": "cli.js" },
  "scripts": { "postinstall": "node install.js" },
  "optionalDependencies": {
    "@yourscope/your-app-darwin-arm64": "0.1.0",
    "@yourscope/your-app-darwin-x64": "0.1.0",
    "@yourscope/your-app-linux-arm64": "0.1.0",
    "@yourscope/your-app-linux-x64": "0.1.0",
    "@yourscope/your-app-win32-arm64": "0.1.0",
    "@yourscope/your-app-win32-x64": "0.1.0"
  }
}
```

The `postinstall` script downloads the binary directly from npm's registry as a fallback when `optionalDependencies` are skipped (e.g., `--ignore-optional`).

See the generated `docs/releases.md` for complete `index.js`, `cli.js`, and `install.js` implementations.

#### Setup

1. Create an npm organization or use your username as scope
2. Create an automation token at [npmjs.com/settings/tokens](https://www.npmjs.com/settings/tokens)
3. Set the secret:

```bash
gh secret set NPM_TOKEN
```

### Setting Up GPG Signing

```bash
# Export your GPG key (base64 encoded)
gpg --export-secret-keys --armor YOUR_KEY_ID | base64 -w0 > key.txt

# Set secrets
gh secret set GPG_RELEASE_KEY < key.txt
gh secret set GPG_PASSPHRASE
rm key.txt
```

## Release Workflow (release.yml)

Automatic releases on merge to main:

| Variable | Purpose |
|----------|---------|
| `AUTO_RELEASE_ENABLED` | Set to `true` to enable |
| `AUTO_RELEASE_DRY_RUN` | Set to `true` for test mode |

When enabled:

1. Runs on every push to `main`
2. Uses git-cliff to check for releasable commits
3. Calculates next semantic version from conventional commits
4. Creates and pushes a tag
5. Tag push triggers `cd.yml`

## Justfile Recipes

| Recipe | Description |
|--------|-------------|
| `just changelog` | Generate CHANGELOG.md |
| `just changelog-preview` | Preview unreleased changes |
| `just bump` | Auto-calculate and apply next version |
| `just release v1.2.3` | Full release with checks |

## cliff.toml Configuration

The git-cliff config:

- Parses conventional commits (`feat:`, `fix:`, etc.)
- Groups changes by type with sorting
- Links PRs and contributors via GitHub API
- Highlights first-time contributors
- Skips chore(release) and dependency bot commits

### Customizing

Edit `commit_parsers` to change grouping:

```toml
commit_parsers = [
  { message = "^feat", group = "Features" },
  { message = "^fix", group = "Bug Fixes" },
  { message = "^doc", group = "Documentation" },
  # Add custom patterns...
]
```

## Semantic Versioning

Version bumps are determined by commit prefixes:

| Commit | Bump | Example |
|--------|------|---------|
| `fix: ...` | Patch | 1.0.0 → 1.0.1 |
| `feat: ...` | Minor | 1.0.0 → 1.1.0 |
| `feat!: ...` | Major | 1.0.0 → 2.0.0 |
| `BREAKING CHANGE:` in body | Major | 1.0.0 → 2.0.0 |

## Pre-releases

Tags with hyphens are treated as pre-releases:

- `v1.0.0` → Full release
- `v1.0.0-beta.1` → Pre-release

Pre-releases:
- Are marked as pre-release on GitHub
- Skip Homebrew formula updates
- Are published to other registries normally

## Design Decisions

### Why not cargo-dist?

cargo-dist is comprehensive but opaque. This template takes a hands-on approach:

1. **Transparent**: All workflow logic is visible in the YAML
2. **Customizable**: Easy to add/remove targets or steps
3. **Debuggable**: Standard GitHub Actions patterns
4. **Flexible**: Mix manual and automatic releases

### Why repo variables instead of template flags?

Publishing targets are runtime decisions, not generation-time decisions:

- Enable npm publishing after getting an npm account
- Disable Homebrew while formula PR is pending
- Toggle SBOM generation for compliance audits

No need to re-run copier to change these.

### Why separate release.yml and cd.yml?

Separation of concerns:

- `release.yml`: Decides IF a release should happen
- `cd.yml`: Handles HOW the release is built/published

This allows manual releases (`just release`) to skip `release.yml` entirely while still using the same build pipeline.

## Related

- [git-cliff documentation](https://git-cliff.org/docs)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [cargo-auditable](https://github.com/rust-secure-code/cargo-auditable)
- [CycloneDX](https://cyclonedx.org/)
