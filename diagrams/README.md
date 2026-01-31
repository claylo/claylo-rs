# Diagrams

Excalidraw diagrams for the README.


## Files

- `choose-your-adventure.excalidraw` — Flowchart: entry points → bad decisions → claylo-rs
- `what-you-get.excalidraw` — Project structure with annotated callouts
- `viewer.html` — Browser-based viewer (requires serve)


## How to Export SVGs

### Option 1: Direct Import to Excalidraw.com

1. Copy the contents of a `.excalidraw` file
2. Go to [excalidraw.com](https://excalidraw.com)
3. Click menu (☰) → Open → paste JSON
4. Adjust styling if needed
5. Select all → Export → SVG
6. Save to `docs/images/`

### Option 2: Use the Viewer

```bash
cd diagrams
npx serve .
# Open http://localhost:3000/viewer.html
```

The viewer uses `convertToExcalidrawElements()` to render the skeleton format.


## Diagram Descriptions

### choose-your-adventure.svg

A "choose your own adventure" flowchart showing multiple entry points:

- Starting a Rust project
- Taming LLM-generated code
- Recovering from Yeoman trauma
- Leveling up an existing project

All paths lead through bad decisions (cargo new, copy-paste, Stack Overflow) to the realization that claylo-rs is the way. The punchline: updates that don't abandon you.

**Vibe:** Dry humor, "I've been burned before" energy.

### what-you-get.svg

Annotated project structure with irreverent callouts:

- `xtask/` → "wait, shell completions just... work?"
- `.claude/` → "AI instructions that aren't vibes-based"
- `my-tool-core/` → "testable without spawning 47 processes"
- `deny.toml` → "that crate with the yanked version? caught."
- `.justfile` → "you will never remember the nextest flags"

**Vibe:** Pleasantly surprised at how much is already done.
