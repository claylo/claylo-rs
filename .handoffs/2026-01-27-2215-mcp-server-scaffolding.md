# Handoff: MCP Server Scaffolding — Complete

**Branch:** `feat/mcp-server`
**Date:** 2026-01-27
**Status:** Implementation complete. Ready for review and merge.

---

## What Was Done

Implemented Phase 7 from the consolidated roadmap: MCP server scaffolding as a Copier template feature.

### Commits (11 total on `feat/mcp-server`)

1. `530c477` — `has_mcp_server` flag + `needs_tokio` computed var in copier.yaml
2. `d827290` — All 4 presets + wrapper alias `[mcp]=has_mcp_server`
3. `f0fc178` — rmcp/schemars/tokio deps in Cargo.toml.jinja
4. `c1bd527` — `needs_tokio` for `#[tokio::main]`, Serve arm in main.rs
5. `99b953b` — `pub mod server;` + `Serve(ServeArgs)` in lib.rs
6. `24e3253` — `serve.rs` command, `mod.rs` → `mod.rs.jinja`
7. `c94265d` — Conditional file/directory pattern reference in template rules
8. `35a906d` — `server.rs.jinja` with ProjectServer + tool_router scaffold
9. `266649e` — `docs/mcp-development.md` conditional guide
10. `451b35b` — 4 bats tests (20/20 pass) + testing docs in rules
11. `128ce9f` — Fix: `ServiceExt` import + `Default` impl for clippy

### Design Decisions

- **Server in lib crate:** `pub mod server;` in lib.rs (not `mod server;` in main.rs). Follows draftkit's architecture where the server struct is part of the library's public API.
- **Generic naming:** `ProjectServer` (not PascalCase of project name). No Jinja PascalCase filter needed.
- **`needs_tokio` computed var:** Consolidates async runtime dependency for OTEL + MCP. Only copier.yaml needs updating when new features need tokio.
- **docs/ not .claude/rules/:** MCP guide placed in `docs/mcp-development.md` to avoid context bloat in every agent session.
- **rmcp 0.14:** Latest release (2026-01-23). Uses `ServiceExt::serve()` for transport binding.

### Verification

- **20/20 conditional file tests** pass (including 4 new MCP tests)
- **Clippy clean** on standard preset with `has_mcp_server=true`
- **60 tests pass** via `cargo nextest run` on generated project
- **`serve` subcommand** appears in `--help` output
- **Minimal preset** still builds clean without any MCP artifacts

## Key Files Changed

| File | Change |
|------|--------|
| `copier.yaml` | `has_mcp_server`, `needs_tokio` |
| `scripts/presets/*.yml` | `has_mcp_server: false` in all 4 |
| `bin/claylo-rs` | `[mcp]=has_mcp_server` alias |
| `template/.../Cargo.toml.jinja` | rmcp, schemars, tokio deps |
| `template/.../main.rs.jinja` | `needs_tokio`, Serve routing |
| `template/.../lib.rs.jinja` | `pub mod server;`, Serve variant |
| `template/.../commands/mod.rs.jinja` | Renamed from mod.rs, conditional serve |
| `template/.../commands/serve.rs` | New conditional file |
| `template/.../server.rs.jinja` | New conditional file (core deliverable) |
| `template/docs/mcp-development.md` | New conditional file |
| `test/conditional_files.bats` | 4 new tests |
| `.claude/rules/template-development.md` | Conditional file patterns + testing docs |
| `.claude/plans/consolidated-status.md` | Phase 7 complete |

## Next Steps

- **Merge to main** after review
- **Phase 8 (Tauri)** is next in the roadmap if desired
- **OAuth MCP auth** noted as post-release milestone (rmcp `auth` feature)
