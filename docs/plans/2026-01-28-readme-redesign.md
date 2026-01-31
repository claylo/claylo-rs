# README Redesign

**Date:** 2026-01-28
**Status:** Ready for implementation

## Context

The current README has an identity crisis.
It mixes end-user documentation with template developer docs,
buries the `claylo-rs` wrapper tool,
and presents exhaustive options tables that overwhelm newcomers.

The primary audience is developers discovering the template for the first time.
Repeat users who need reference material can go to `docs/`.


## Design Goals

- Lead with sizzle and personality (dry humor, "I've been burned before" energy)
- Show the `claylo-rs` wrapper as THE way to use the template
- Emphasize the update story — this isn't one-and-done like Yeoman or cargo-generate
- Move reference tables and developer docs to `docs/`
- Two Excalidraw diagrams for visual interest


## File Structure

```
README.md              → Discovery, quick start, "why this exists"
docs/
  reference.md         → Full options tables, all flags
  updating.md          → Update workflow, bulk updates
  development.md       → Template development, Jinja2, testing
  presets.md           → Deep dive on preset contents
```


## README Structure

### 1. Title + One-liner

```markdown
# claylo-rs

Production-ready Rust CLI scaffolding. Opinionated defaults. Updates that don't abandon you.
```

### 2. Flowchart (Excalidraw SVG)

A hand-drawn "choose your own adventure" diagram with multiple entry points:

**Entry points:**

- "Starting a Rust project?"
- "Taming a Rust project some LLM just dropped on you?"
- "Still recovering from your last Yeoman disaster?"
- "Got a project in decent shape you want to level up?"

**Bad branches (things we've all done):**

- "`cargo new --lib`?" → later: "why didn't I set up logging"
- "Scavenge stuff from that other project?" → later: "where did I put that tracing setup"
- "Trust this rando's template?" → leads to claylo-rs with note: "at least this rando has opinions about logging"

All paths eventually lead to claylo-rs or pain.

### 3. Installation

```markdown
## Install

\`\`\`bash
brew install claylo/brew/claylo-rs
\`\`\`

Requires [copier](https://copier.readthedocs.io/) (`pipx install copier` or `uv tool install copier`).
If you're allergic to Python, we understand — it stays out of your generated project.
```

### 4. Quick Start

Three examples showing the spectrum:

```markdown
## Quick Start

\`\`\`bash
# Sensible defaults: CLI + config + logging + workspace layout
claylo-rs new ./my-tool --owner myorg --copyright "Your Name"

# Full send: benchmarks, OpenTelemetry, the works
claylo-rs new ./my-tool --preset full +otel

# Minimal: just the binary (we've all been there)
claylo-rs new ./my-tool --preset minimal
\`\`\`
```

**The reveal** — what you just got:

- A CLI binary that handles `--verbose` and `--quiet`
- JSONL logging that doesn't pollute stdout
- Config file discovery that checks all the right places
- A `.justfile` so you don't remember `cargo nextest run --all-features`

**The hook** — the update story teaser:

> Six months later, the template adds MCP server scaffolding. You run:
> ```bash
> claylo-rs update . +mcp
> ```
> Three-way merge. Your code stays. New features land. No copy-paste archaeology.

### 5. Presets Overview

Brief, opinionated descriptions:

| Preset | The Vibe |
|--------|----------|
| **minimal** | Just the binary. No config, no logging, no training wheels. For when you know exactly what you're doing, or want to find out the hard way. |
| **standard** | The "you'll thank yourself later" tier. CLI + core library + config discovery + JSONL logging + xtask automation. Most projects land here. |
| **full** | Everything. Benchmarks, editor configs, markdown linting, environment files. For projects that will outlive your current job. |

Show mixing presets with flags:

```bash
claylo-rs new ./my-tool --preset standard +otel
claylo-rs new ./my-tool --preset full -bench
claylo-rs new ./my-tool --preset minimal +config
```

Link to `docs/reference.md` for full flag list.

### 6. What You Get (Excalidraw SVG)

Annotated project structure diagram with irreverent callouts:

**Project tree on left, arrows pointing to:**

- `xtask/` → "wait, shell completions just... work?"
- `.claude/` → "AI instructions that aren't vibes-based"
- `my-tool-core/` → "your logic, testable without spawning 47 processes"
- `deny.toml` → "that one crate with the yanked version? caught."
- `.justfile` → "you will never remember the nextest flags. that's fine."

Maybe a tiny figure in the corner: "I usually copy-paste this from my last project" with a red X.

Brief text after diagram:

> The structure follows [ADR-0001](docs/decisions/0001-workspace-structure-with-separate-core-library.md) if you want the reasoning.
> Short version: your CLI is a thin shell, your logic is a library, and you can test without `assert_cmd` for most things.

### 7. Claude Code Integration

```markdown
## Works with Claude Code

The generated project includes `.claude/` with skills, rules, and commands tuned for Rust development.

"Add a new subcommand" → There's a skill for that.
"Set up config file support" → Already documented.
"Why is clippy yelling at me" → The rules explain the lint choices.

You're not starting from scratch. Neither is your AI.

\`\`\`bash
# Skip if you have your own global Claude setup
claylo-rs new ./my-tool -claude_skills -claude_rules
\`\`\`
```

### 8. The Update Story

```markdown
## This Isn't One-and-Done

Yeoman generates and ghosts you. `cargo-generate` copies and walks away.

Copier tracks what it generated. When the template improves, your project can too:

\`\`\`bash
# Six months later
claylo-rs update .
\`\`\`

Three-way merge. Your changes stay. Template updates land. No archaeology required.
```

### 9. One More Thing

```markdown
## "Where's the release automation?"

The CI/CD matrix. The cargo-dist config. The changelog generation.
The "publish to crates.io on tag" workflow.

Not here.

This template is about **making the thing**. Clean scaffolding, sensible defaults, get to work.

Releasing the thing? That's *claylo-rs-???* (name TBD). A separate template you layer on top:

\`\`\`bash
# First, make the thing
claylo-rs new ./my-tool --preset standard

# Later, when you're ready to ship
copier copy gh:claylo/claylo-rs-??? ./my-tool
\`\`\`

Copier merges them. One project, multiple templates, each doing one job well.
Your scaffolding template doesn't need opinions about your release cadence.
```

### 10. Footer

Links to documentation:

- **Reference:** `docs/reference.md` — All flags, all options, alphabetized for the ctrl-F crowd.
- **Presets deep dive:** `docs/presets.md` — What each preset actually enables.
- **Updating projects:** `docs/updating.md` — The update workflow, bulk updates, conflict resolution.
- **Template development:** `docs/development.md` — For contributors. Jinja2, testing, the whole mess.


## Diagrams to Create

1. **Flowchart** (`docs/images/choose-your-adventure.svg`)
   - Entry points at top
   - Decision branches with humor
   - All roads lead to claylo-rs or regret

2. **Project structure** (`docs/images/what-you-get.svg`)
   - Tree on left
   - Hand-drawn arrows with callouts on right
   - "I copy-paste this" figure with X


## Documentation Files to Create

1. **`docs/reference.md`**
   - Move all options tables from current README
   - Alphabetize flags
   - Group by category (project identity, features, dotfiles, etc.)

2. **`docs/presets.md`**
   - What each preset enables (tables showing flag values)
   - When to use each one

3. **`docs/updating.md`**
   - `claylo-rs update` workflow
   - Bulk update script docs (from current README)
   - Conflict resolution tips

4. **`docs/development.md`**
   - Move template development section from current README
   - Jinja2 patterns
   - Testing the template
   - Contributing guidelines


## Implementation Order

1. Create `docs/images/` directory
2. Create placeholder diagrams (or final if we have Excalidraw ready)
3. Create the four docs files with content moved from README
4. Rewrite README with new structure
5. Verify all links work
