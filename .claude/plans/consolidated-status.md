# claylo-rs Implementation Status

**Date:** 2026-01-22
**Status:** Phases 1-5 complete; Phase 4 (Docker testing) fully operational

---

## Completed Work

### Phase 1: Documentation & Polish ✅
- README badges (CI, crates.io, docs.rs, MSRV)
- docs/releasing.md (cog + cargo-dist workflow)
- `#![warn(missing_docs)]` workspace lint
- Module-level doc comments
- **Root README updates:**
  - Renamed "Logging" → "Logging and Tracing" with CLI flag docs (`-v`, `-vv`, `--quiet`, `RUST_LOG`)
  - Clarified OTEL adds trace *export*, not tracing itself
  - Added "Zero-Cost Tracing" section for developers from GC languages

### Phase 1.5: Evidence-Based Testing ✅
- Results directory: `target/template-tests/results/YYYYMMDD-HHMM/`
- Feature verification (binary execution, log files, config discovery)
- Evidence artifacts (SUMMARY.md, feature checklists)

### Phase 1.6: AgentSkill for Adding Commands ✅
- Created `adding-commands` skill (conditional on features)
- Made Claude config optional (`has_claude`, `has_claude_skills`, etc.)

### Phase 2: Developer Experience ✅
- `just bootstrap` command
- `watch` and `release-check` recipes
- Error context examples (`.with_context()`)
- `--json` structured output pattern

### Phase 2.5: Template Tracing Instrumentation ✅
- Added `#[tracing::instrument]` to `cmd_info` command
- Added `Debug` derive to `InfoArgs` struct
- Added debug-level logging for command flags (`args.json`, `global_json`, `json_output`)
- Added debug logging for global CLI flags in `main.rs` (`verbose`, `quiet`, `json`, `color`, `chdir`)
- Verified traces flow to Grafana Tempo when OTEL enabled

### Phase 5: Modularization ✅ (mostly)

**5.1 Hook system choice** ✅
- Added `hook_system` to copier.yaml: cog, pre-commit, lefthook, none
- Default: `cog` for standard/full, `none` for minimal
- Conditional hook config generation

**5.2 Modular flags** ✅
- ~25 new flags for granular control:
  - Dotfiles: `has_yamlfmt`, `has_yamllint`, `has_editorconfig`, `has_env_files`
  - Core files: `has_agents_md`, `has_just`, `has_gitattributes`
  - GitHub: `has_github`, `has_security_md`, `has_issue_templates`, `has_pr_templates`
  - Markdown: `has_md`, `has_md_strict`
  - Skills: `has_skill_markdown_authoring`, `has_skill_capturing_decisions`, `has_skill_using_git`

**5.3 Benchmarking flags** ✅
- Added `has_gungraun` (default: false, requires Valgrind)
- Divan and hyperfine bundled with `has_benchmarks`

**5.4 Generated benchmark code passes clippy** ✅
- Fixed: Added `#![allow(missing_docs)]` to gungraun code generator

**5.5 Conditional file tests** ✅
- Added 12 fast tests that verify file inclusion/exclusion without cargo builds
- Tests run before preset tests in `./scripts/test-template.sh`

**5.8 Config crate feature cleanup** ✅
- Removed INI and RON format support (unused, adds compile overhead)
- Config crate now uses only: `toml`, `yaml`, `json`, `json5`
- Updated all documentation and example files

### Phase 3: Testing Improvements ✅

**3.1 Add config integration tests** ✅
- File: `template/crates/{{project_name}}/tests/config_integration.rs.jinja`
- Conditional on `has_config`
- 18 tests covering: discovery, formats (TOML/YAML/JSON/JSON5), precedence, boundaries, errors

### Phase 4: Docker-Based Testing Infrastructure ✅

**4.1 OTEL/Observability stack** ✅
- Grafana LGTM (all-in-one): `grafana/otel-lgtm:latest`
- Config: `scripts/docker/docker-compose.yml`
- Endpoints: Grafana `:3000`, OTLP gRPC `:4317`, OTLP HTTP `:4318`
- Just recipes: `docker-up`, `docker-down`, `docker-logs`, `docker-status`
- **Verified working:** Traces from generated `standard-otel` project appear in Tempo

**4.2 Local crates.io** ✅
- Running actual [crates.io](https://github.com/rust-lang/crates.io) locally via Docker
- Location: `~/scratch/rust/crates.io/` → `docker compose up -d`
- Ports: Frontend `:4200`, Backend API `:8888`, PostgreSQL `:5432`
- Publish: `cargo publish --index http://localhost:8888/git/index --token $TOKEN`
- Token: Set up GitHub OAuth app, then get token from http://localhost:4200/me

**4.3 GitHub Actions local testing (act)** ✅
- [nektos/act](https://nektosact.com/) installed via `brew install act`
- Run on-demand: `act -l` (list), `act push` (simulate push), `act -j <job>`

**4.4 Docker Compose orchestration** ✅
- OTEL stack: `scripts/docker/docker-compose.yml`
- crates.io: `~/scratch/rust/crates.io/docker-compose.yml` (separate)
- Just recipes: `docker-up`, `docker-down`, `docker-logs`, `docker-status`

---

## Remaining Work

### Phase 5: Modularization (Optional Remaining)

**5.6 Create alternative hook config files** (Optional)
- `.pre-commit-config.yaml.jinja` - pre-commit hooks
- `lefthook.yml.jinja` - lefthook hooks
- Currently only `cog.toml` exists; alternatives would require creating these

**5.7 ADR amendments** (Optional)
- ADR-0003: Add conditional adoption section for hook_system
- ADR-0008: Add tiered adoption section for benchmarking

### Phase 6: WASM & FFI Support (Deferred)
- `has_wasm` - wasm-bindgen, wasm-pack integration
- `has_ffi` - cdylib target, cbindgen for headers

### Phase 7: MCP Server Scaffolding ✅
- `has_mcp_server` flag (default: false, gated on `has_cli`)
- `needs_tokio` computed variable consolidating async runtime needs
- `serve` subcommand in CLI binary routing to `ProjectServer`
- `server.rs` with `#[tool_router]`/`#[tool_handler]` scaffold (rmcp 0.14)
- Example tool with `schemars` parameter struct (conditional on `has_core_library`)
- `docs/mcp-development.md` guide (not in `.claude/rules/` — avoids context bloat)
- 4 conditional file tests + full build verification (clippy clean, 60 tests pass)

**Post-release milestone:** OAuth-based MCP authentication (see rmcp `auth` feature)

### Phase 8: Tauri App Support (Queued)
- Option to scaffold a Tauri desktop app in generated project
- New flag: `has_tauri` (default: false)
- Integration with existing CLI/core library structure

### Phase 9: Release Cleanup (Done)
- Stripped all release-related infrastructure from template (2026-01-27)
- Release workflows moved to separate template concept
- Removed: `release_tier`, `versioning`, `team_auto_publish`, `has_cog`, cog.toml, bump.yml, publish.yml, cargo-dist config, releasing.md
- See `ref/release-features-removed.md` for comprehensive removal inventory
- See `.claude/plans/phase-9-release-workflow.md` for the cleanup plan

### Phase 10: Template Polish (Queued)

**10.1 Bootstrap message in copier.yaml**
- Add `just bootstrap` instruction to `_message_after_copy` block
- Currently only documented in README.md

**10.2 Clippy/build preference tiers**
- Not everyone wants `clippy::nursery` level strictness
- Options: `strict` (current), `standard`, `relaxed`
- New variable: `lint_level` or `clippy_preset`
- Affects `[workspace.lints.clippy]` in generated Cargo.toml

---

## Test Results

All 4 presets pass:
```
✓ 20 conditional file tests passed (incl. 4 MCP server tests)
✓ minimal preset passed (24 tests)
✓ standard preset passed (61 tests)
✓ standard + MCP server passed (60 tests, clippy clean)
✓ standard-otel preset passed (65 tests)
✓ full preset passed (65 tests)
```

OTEL traces verified flowing to Grafana Tempo via local Docker stack.

---

## Files to Clean Up

These plan files are now superseded by this consolidated status:
- `modularization-revisit.md` - planning complete, work done
- `next-steps-implementation.md` - phases 1-2 complete, phase 5 tracked here
- `template-modularization.md` - work complete

