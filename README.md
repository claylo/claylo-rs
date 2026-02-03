# claylo-rs

Production-ready Rust CLI scaffolding.
Opinionated defaults.
Updates that don't abandon you.

![Choose your adventure flowchart](docs/images/choose-your-adventure.svg)

## Install

```bash
brew install claylo/brew/claylo-rs
```

Requires [copier](https://copier.readthedocs.io/) (`uv tool install copier` or `pipx install copier`).
If you're not a Python fan, don't worry — it stays out of your generated project.


## Quick Start

```bash
# Sensible defaults: CLI + config + logging + workspace layout
claylo-rs new ./my-tool --owner myorg --copyright "Your Name"

# Full send: benchmarks, OpenTelemetry, the works
claylo-rs new ./my-tool --preset full +otel

# Minimal: just the binary (we've all been there)
claylo-rs new ./my-tool --preset minimal
```

You now have a Rust workspace with:

- A CLI binary that handles `--verbose` and `--quiet`
- JSONL logging that doesn't pollute stdout (safe for pipes and MCP servers)
- Config file discovery that checks all the right places
- A `.justfile` so you never type `cargo nextest run --all-features` again

Six months later, the template adds MCP server scaffolding.
You run:

```bash
claylo-rs update . +mcp
```

Three-way merge. Your code stays. New features land. No copy-paste-pray.


## Presets

Pick a starting point. Override anything with `+flag` or `-flag`.

| Preset | The Vibe |
|--------|----------|
| **minimal** | Just the binary. No config, no logging, no training wheels. For when you know exactly what you're doing, or want to find out the hard way. |
| **standard** | The "you'll thank yourself later" tier. CLI + core library + config discovery + JSONL logging + xtask automation. Most projects land here. |
| **full** | Everything. Benchmarks, editor configs, markdown linting, environment files. For projects that will outlive your current job. |

```bash
# Standard with OpenTelemetry tracing
claylo-rs new ./my-tool --preset standard +otel

# Full but skip the benchmarks
claylo-rs new ./my-tool --preset full -bench

# Minimal but add config support
claylo-rs new ./my-tool --preset minimal +config
```

See [docs/reference.md](docs/reference.md) for the full flag list.


## What You Get

![What you get - annotated project structure](docs/images/what-you-get.svg)

```
my-tool/
├── crates/
│   ├── my-tool/           # CLI binary
│   │   ├── src/
│   │   │   ├── main.rs    # Entry point, args, logging init
│   │   │   └── commands/  # Subcommand handlers
│   │   └── tests/
│   └── my-tool-core/      # Library crate (your actual logic)
├── xtask/                 # Build automation (man pages, completions)
├── .claude/               # Claude Code skills, rules, commands
├── .justfile              # Task runner recipes
├── Cargo.toml             # Workspace manifest
└── deny.toml              # cargo-deny config
```

**Separate binary and library** — Your CLI is a thin wrapper.
The logic lives in `-core` where it's testable without spawning processes.

**xtask instead of build scripts** — `cargo xtask install` generates man pages and shell completions.
No Makefile, no external tools.

**Logging that respects stdout** — JSONL goes to files.
Stdout stays clean for pipes, MCP servers, and tools that need structured output.

**Config discovery built in** — Checks `./my-tool.toml`, `~/.config/my-tool/config.toml`, and environment variables.
Hierarchical, overridable, boring in the best way.

The structure follows [ADR-0001](docs/decisions/0001-workspace-structure-with-separate-core-library.md) if you want the reasoning.


## Works with Claude Code

The generated project includes `.claude/` with skills, and commands tuned for Rust development.

"Add a new subcommand" → There's a skill for that.
"Set up config file support" → Already documented.
"Why is clippy yelling at me" → The rules explain the lint choices.

You're not starting from scratch. Neither is your AI.

```bash
# Skip if you have your own global Claude setup
claylo-rs new ./my-tool -claude_skills -claude_rules
```


## This Isn't One-and-Done

Yeoman generates and ghosts you.
`cargo-generate` copies and walks away.

Copier tracks what it generated.
When the template improves, your project can too:

```bash
# Six months later
claylo-rs update .
```

Three-way merge.
Your changes stay.
Template updates land.
No archaeology required.

See [docs/updating.md](docs/updating.md) for the full workflow.


## "What about release automation?"

The CI/CD matrix, cargo-dist config, changelog generation, and "publish to crates.io on tag" workflow are all included.

See [docs/releases.md](docs/releases.md) for the full details.

Not your style? The release system is easy to turn off — just delete the workflows you don't want.

---

**Reference:** [docs/reference.md](docs/reference.md) — All flags, all options.

**Presets deep dive:** [docs/presets.md](docs/presets.md) — What each preset enables.

**Updating projects:** [docs/updating.md](docs/updating.md) — The update workflow, bulk updates.

**Template development:** [docs/development.md](docs/development.md) — For contributors.


## License

Dual-licensed under MIT and Apache-2.0.
