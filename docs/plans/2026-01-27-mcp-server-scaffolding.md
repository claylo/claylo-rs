# MCP Server Scaffolding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `has_mcp_server` flag to the Copier template that scaffolds a `serve` subcommand exposing the core library over the Model Context Protocol via stdio.

**Architecture:** The MCP server is a `serve` subcommand inside the existing CLI binary crate — a peer interface to the core library, just like the CLI commands. It uses the `rmcp` crate (official Rust MCP SDK) with stdio transport, `#[tool_router]`/`#[tool_handler]` macros, and `schemars` for parameter schemas. When `has_core_library` is true, the generated server struct demonstrates calling core library types; when false, it provides a standalone example tool.

**Tech Stack:** `rmcp` 0.14 (server + transport-io + macros), `schemars` 1.0, `tokio` 1 (rt-multi-thread + macros)

**Reference impl:** `~/source/lovelesslabs/draftkit/crates/draftkit/src/server.rs` + `commands/serve.rs`

---

## Task 1: Add `has_mcp_server` and `needs_tokio` to copier.yaml

**Files:**
- Modify: `copier.yaml:220-224` (after `has_opentelemetry`)
- Modify: `copier.yaml:284-287` (computed variables section, after `has_xtask`)

**Step 1: Add `has_mcp_server` flag**

Insert after the `has_opentelemetry` block (after line 224):

```yaml
has_mcp_server:
  type: bool
  default: false
  when: "{{ has_cli }}"
  help: "Include MCP server (Model Context Protocol) as a 'serve' subcommand"
```

**Step 2: Add `needs_tokio` computed variable**

Insert after the `has_xtask` computed variable block (after line 287):

```yaml
needs_tokio:
  type: bool
  default: "{{ has_opentelemetry or has_mcp_server }}"
  when: false  # Don't prompt, just compute
```

**Step 3: Run copier.yaml linting**

Run: `just fmt && just lint`
Expected: Clean

**Step 4: Commit**

```bash
git add copier.yaml
git commit -m "$(cat <<'EOF'
feat(template): add has_mcp_server flag and needs_tokio computed var

Introduces has_mcp_server (default: false, gated on has_cli) for
scaffolding an MCP stdio server as a serve subcommand. The needs_tokio
computed var consolidates the async runtime dependency check across
has_opentelemetry and has_mcp_server.
EOF
)"
```

---

## Task 2: Update preset data files and wrapper alias

**Files:**
- Modify: `scripts/presets/minimal.yml`
- Modify: `scripts/presets/standard.yml`
- Modify: `scripts/presets/standard-otel.yml`
- Modify: `scripts/presets/full.yml`
- Modify: `bin/claylo-rs` (ALIAS_MAP, around line 22-52)

**Step 1: Add `has_mcp_server: false` to all preset files**

Add after `has_opentelemetry` in each file:
```yaml
has_mcp_server: false
```

All four presets get `false` — MCP server is always opt-in.

**Step 2: Add wrapper alias**

In `bin/claylo-rs`, add to the `ALIAS_MAP` associative array (alphabetically among the existing entries):

```bash
[mcp]=has_mcp_server
```

**Step 3: Commit**

```bash
git add scripts/presets/ bin/claylo-rs
git commit -m "$(cat <<'EOF'
feat(template): add has_mcp_server to presets and wrapper alias

All presets default to false. Wrapper alias [mcp]=has_mcp_server
enables +mcp toggle from the CLI.
EOF
)"
```

---

## Task 3: Update CLI crate Cargo.toml.jinja for MCP dependencies

**Files:**
- Modify: `template/crates/{{project_name if has_cli else "__skip_cli__"}}/Cargo.toml.jinja`

**Step 1: Add rmcp, schemars, and tokio dependencies**

The tokio dependency currently only exists when `has_opentelemetry` is true. Refactor the conditional to use `needs_tokio` and add rmcp + schemars for `has_mcp_server`.

In the `[dependencies]` section, make these changes:

1. Replace the existing `has_opentelemetry` tokio line:
```
{% if has_opentelemetry -%}
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
{% endif -%}
```
With the broader `needs_tokio` condition:
```
{% if needs_tokio -%}
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
{% endif -%}
```

2. Add rmcp and schemars after the serde_json line, conditional on `has_mcp_server`:
```
{% if has_mcp_server -%}
rmcp = { version = "0.14", features = ["server", "transport-io", "macros"] }
schemars = "1.0"
{% endif -%}
```

**Step 2: Verify template renders**

Run copier copy with a minimal preset + `has_mcp_server=true` and inspect the generated Cargo.toml. No cargo build yet — just file inspection:

```bash
copier copy --trust --defaults \
  --data-file scripts/presets/standard.yml \
  --data has_mcp_server=true \
  . target/template-tests/mcp-cargo-check
grep -A2 'rmcp' target/template-tests/mcp-cargo-check/crates/test-standard/Cargo.toml
grep 'schemars' target/template-tests/mcp-cargo-check/crates/test-standard/Cargo.toml
grep 'tokio' target/template-tests/mcp-cargo-check/crates/test-standard/Cargo.toml
```

Expected: All three deps present with correct versions.

**Step 3: Commit**

```bash
git add template/crates/*/Cargo.toml.jinja
git commit -m "$(cat <<'EOF'
feat(template): add rmcp, schemars, tokio deps for MCP server

Adds rmcp 0.14 (server + transport-io + macros) and schemars 1.0
conditional on has_mcp_server. Refactors tokio conditional to use
needs_tokio computed var so both OTEL and MCP can require the
async runtime independently.
EOF
)"
```

---

## Task 4: Update main.rs.jinja for async main and serve command routing

**Files:**
- Modify: `template/crates/{{project_name if has_cli else "__skip_cli__"}}/src/main.rs.jinja`

**Step 1: Broaden the `#[tokio::main]` condition**

Current logic (line 21-26):
```
{% if has_opentelemetry -%}
#[tokio::main]
async fn main() -> anyhow::Result<()> {
{% else -%}
fn main() -> anyhow::Result<()> {
{% endif -%}
```

Replace with:
```
{% if needs_tokio -%}
#[tokio::main]
async fn main() -> anyhow::Result<()> {
{% else -%}
fn main() -> anyhow::Result<()> {
{% endif -%}
```

**Step 2: Add the `Serve` command route**

In *both* `match cli.command` blocks (the one inside the observability conditional and the `else` one), add the Serve arm:

```
{% if has_mcp_server -%}
        Commands::Serve(args) => commands::serve::cmd_serve(args).await,
{% endif -%}
```

Note: When `has_mcp_server` is true, `needs_tokio` is always true, so main is always async. The `.await` is safe.

**Step 3: Add `mod server;` import at top**

After `mod observability;` (or after the existing module imports if observability is absent):

```
{% if has_mcp_server %}
mod server;
{% endif %}
```

**Step 4: Commit**

```bash
git add template/crates/*/src/main.rs.jinja
git commit -m "$(cat <<'EOF'
feat(template): route serve subcommand in main.rs

Broadens tokio::main condition to needs_tokio. Adds Serve command arm
that dispatches to cmd_serve().await. Adds conditional mod server.
EOF
)"
```

---

## Task 5: Update lib.rs.jinja for Serve variant in Commands enum

**Files:**
- Modify: `template/crates/{{project_name if has_cli else "__skip_cli__"}}/src/lib.rs.jinja`

**Step 1: Add `serve` module to commands**

The lib.rs exposes `pub mod commands;` already. The `commands/mod.rs` needs a conditional entry (handled in Task 6). No changes to lib.rs module declarations needed — `mod server;` goes in main.rs because it's a private impl detail.

**Step 2: Add Serve variant to Commands enum**

In the `Commands` enum (currently line 57-61):

```rust
#[derive(Subcommand)]
pub enum Commands {
    /// Show package information
    Info(commands::info::InfoArgs),
{% if has_mcp_server %}
    /// Start MCP (Model Context Protocol) server on stdio
    Serve(commands::serve::ServeArgs),
{% endif %}
}
```

**Step 3: Commit**

```bash
git add template/crates/*/src/lib.rs.jinja
git commit -m "$(cat <<'EOF'
feat(template): add Serve variant to Commands enum

Conditionally includes Serve(ServeArgs) subcommand when
has_mcp_server is true.
EOF
)"
```

---

## Task 6: Create commands/serve.rs template

**Files:**
- Create: `template/crates/{{project_name if has_cli else "__skip_cli__"}}/src/commands/{{"serve.rs" if has_mcp_server else "__skip_serve__.rs"}}`
- Modify: `template/crates/{{project_name if has_cli else "__skip_cli__"}}/src/commands/mod.rs`

**Step 1: Create serve.rs**

This is a plain file (no `.jinja` suffix needed — no template variables inside):

```rust
//! MCP server command implementation

use anyhow::Result;
use clap::Args;

use crate::server::ProjectServer;

/// Arguments for the `serve` subcommand.
#[derive(Args, Debug)]
pub struct ServeArgs {}

/// Start the MCP server on stdio.
///
/// This launches a Model Context Protocol server that communicates over
/// stdin/stdout using JSON-RPC. All logging goes to stderr to keep the
/// stdio transport clean.
///
/// # Usage
///
/// Configure in your MCP client (e.g., Claude Code `settings.json`):
///
/// ```json
/// {
///   "mcpServers": {
///     "my-project": {
///       "command": "my-project",
///       "args": ["serve"]
///     }
///   }
/// }
/// ```
pub async fn cmd_serve(_args: ServeArgs) -> Result<()> {
    tracing::info!("Starting MCP server on stdio");

    let server = ProjectServer::new();
    let service = server.serve(rmcp::transport::stdio()).await?;
    service.waiting().await?;

    Ok(())
}
```

Wait — this file references `crate::server::ProjectServer` but the actual struct name should use the project name. This needs to be a `.jinja` file after all.

Revised: Create as `serve.rs.jinja`:

```
//! MCP server command implementation

use anyhow::Result;
use clap::Args;

use crate::server::{{ crate_name | pascal_case }}Server;

/// Arguments for the `serve` subcommand.
#[derive(Args, Debug)]
pub struct ServeArgs {}

/// Start the MCP server on stdio.
///
/// This launches a Model Context Protocol server that communicates over
/// stdin/stdout using JSON-RPC. All logging goes to stderr to keep the
/// stdio transport clean.
pub async fn cmd_serve(_args: ServeArgs) -> Result<()> {
    tracing::info!("Starting MCP server on stdio");

    let server = {{ crate_name | pascal_case }}Server::new();
    let service = server.serve(rmcp::transport::stdio()).await?;
    service.waiting().await?;

    Ok(())
}
```

Hmm — Copier/Jinja2 doesn't have a `pascal_case` filter natively. Let me check what the template does elsewhere for casing.

**Decision checkpoint:** The draftkit code uses `DraftkitServer` (PascalCase of the project name). But Copier Jinja2 doesn't have a built-in PascalCase filter. Options:

(a) Use a generic name like `ProjectServer` — works regardless of project name, no filter needed.
(b) Add a computed variable `server_struct_name` in copier.yaml — fragile, over-engineering.

**Use option (a): `ProjectServer`.** It's a scaffold name that users will rename when they customize. Matches the "start simple" philosophy.

Revised `serve.rs` (no `.jinja` needed):

```rust
//! MCP server command implementation

use anyhow::Result;
use clap::Args;

use crate::server::ProjectServer;

/// Arguments for the `serve` subcommand.
#[derive(Args, Debug)]
pub struct ServeArgs {}

/// Start the MCP server on stdio.
///
/// This launches a Model Context Protocol server that communicates over
/// stdin/stdout using JSON-RPC. All logging goes to stderr to keep the
/// stdio transport clean.
pub async fn cmd_serve(_args: ServeArgs) -> Result<()> {
    tracing::info!("Starting MCP server on stdio");

    let server = ProjectServer::new();
    let service = server.serve(rmcp::transport::stdio()).await?;
    service.waiting().await?;

    Ok(())
}
```

**Step 2: Update commands/mod.rs**

Current content:
```rust
//! Command implementations

pub mod info;
```

Make it a jinja template (`mod.rs` → `mod.rs.jinja`? No — check if it's already .jinja).

The file is currently `mod.rs` (not `.jinja`). It needs a conditional line. Rename to `mod.rs.jinja`:

```
//! Command implementations

pub mod info;
{% if has_mcp_server %}
pub mod serve;
{% endif %}
```

Wait — renaming the existing `mod.rs` to `mod.rs.jinja` would change template behavior since `_templates_suffix: .jinja` strips the suffix. The output file will be `mod.rs` either way. But the existing `mod.rs` is currently NOT a jinja template, and adding jinja conditionals requires it to become one.

**Rename** `template/.../commands/mod.rs` → `template/.../commands/mod.rs.jinja` and add the conditional.

**Step 3: Commit**

```bash
git add template/crates/*/src/commands/
git commit -m "$(cat <<'EOF'
feat(template): add serve command module

Thin async command that boots ProjectServer on rmcp stdio transport.
Conditionally included in commands/mod.rs when has_mcp_server is true.
EOF
)"
```

---

## Task 7: Create server.rs.jinja template

**Files:**
- Create: `template/crates/{{project_name if has_cli else "__skip_cli__"}}/src/{{"server.rs" if has_mcp_server else "__skip_mcp_server__.rs"}}.jinja`

**Step 1: Write the server template**

This is the core deliverable. It follows draftkit's patterns exactly:

```rust
{% if has_mcp_server -%}
//! MCP (Model Context Protocol) server implementation.
//!
//! This module exposes project functionality over the MCP protocol, making it
//! available to AI assistants (Claude Code, Cursor, etc.) via stdio transport.
//!
//! # Architecture
//!
//! The MCP server is a presentation layer — it wraps the same core library that
//! the CLI commands use. Each `#[tool]` method should delegate to core library
//! functions rather than implementing business logic directly.
//!
//! # Adding Tools
//!
//! 1. Define a parameter struct with `Deserialize` + `JsonSchema`
//! 2. Add a `#[tool(description = "...")]` method to the `#[tool_router]` impl
//! 3. Call core library functions, convert errors to `McpError`
//! 4. Return `CallToolResult::success(vec![Content::text(...)])`

use rmcp::handler::server::wrapper::Parameters;
use rmcp::model::{
    CallToolResult, Content, Implementation, ServerCapabilities, ServerInfo,
};
use rmcp::{ErrorData as McpError, ServerHandler, tool, tool_handler, tool_router};
{% if has_core_library -%}
use rmcp::schemars;
{% endif %}

{% if has_core_library -%}
/// Parameters for the `get_info` tool.
#[derive(Debug, serde::Deserialize, schemars::JsonSchema)]
pub struct GetInfoParams {
    /// Output format: "text" or "json"
    #[serde(default = "default_format")]
    pub format: String,
}

fn default_format() -> String {
    "text".to_string()
}

{% endif -%}
/// MCP server exposing project functionality to AI assistants.
///
/// Each `#[tool]` method in the `#[tool_router]` impl block is automatically
/// registered and callable via the MCP protocol.
#[derive(Clone)]
pub struct ProjectServer {
    tool_router: rmcp::handler::server::router::tool::ToolRouter<Self>,
}

#[tool_router]
impl ProjectServer {
    /// Create a new MCP server instance.
    pub fn new() -> Self {
        Self {
            tool_router: Self::tool_router(),
        }
    }

{% if has_core_library -%}
    /// Get project information.
    #[tool(description = "Get project name, version, and description")]
    fn get_info(
        &self,
        Parameters(params): Parameters<GetInfoParams>,
    ) -> Result<CallToolResult, McpError> {
        let info = serde_json::json!({
            "name": env!("CARGO_PKG_NAME"),
            "version": env!("CARGO_PKG_VERSION"),
            "description": env!("CARGO_PKG_DESCRIPTION"),
        });

        let text = if params.format == "json" {
            serde_json::to_string_pretty(&info)
                .map_err(|e| McpError::internal_error(format!("serialization error: {e}"), None))?
        } else {
            format!(
                "{} v{}\n{}",
                env!("CARGO_PKG_NAME"),
                env!("CARGO_PKG_VERSION"),
                env!("CARGO_PKG_DESCRIPTION"),
            )
        };

        Ok(CallToolResult::success(vec![Content::text(text)]))
    }
{% else -%}
    /// Get project information.
    #[tool(description = "Get project name and version")]
    fn get_info(&self) -> Result<CallToolResult, McpError> {
        let text = format!(
            "{} v{}",
            env!("CARGO_PKG_NAME"),
            env!("CARGO_PKG_VERSION"),
        );
        Ok(CallToolResult::success(vec![Content::text(text)]))
    }
{% endif -%}
}

#[tool_handler]
impl ServerHandler for ProjectServer {
    fn get_info(&self) -> ServerInfo {
        ServerInfo {
            protocol_version: Default::default(),
            capabilities: ServerCapabilities::builder()
                .enable_tools()
                .build(),
            server_info: Implementation {
                name: env!("CARGO_PKG_NAME").to_string(),
                version: env!("CARGO_PKG_VERSION").to_string(),
            },
            instructions: Some(format!(
                "{} MCP server. Use tools to interact with project functionality.",
                env!("CARGO_PKG_NAME"),
            )),
        }
    }
}
{%- endif %}
```

**Step 2: Verify template renders (no build yet)**

```bash
rm -rf target/template-tests/mcp-server-check
copier copy --trust --defaults \
  --data-file scripts/presets/standard.yml \
  --data has_mcp_server=true \
  . target/template-tests/mcp-server-check
cat target/template-tests/mcp-server-check/crates/test-standard/src/server.rs
```

Expected: Clean Rust source with no `{%` or `{{` artifacts.

**Step 3: Commit**

```bash
git add template/crates/*/src/
git commit -m "$(cat <<'EOF'
feat(template): add MCP server.rs with tool_router scaffold

Conditional on has_mcp_server. Provides ProjectServer struct with one
example tool (get_info), tool_router/tool_handler macro setup, and
ServerHandler impl. When has_core_library is true, the example tool
demonstrates schemars parameter structs.
EOF
)"
```

---

## Task 8: Create MCP server development guide in docs/

**Files:**
- Create: `template/docs/{{"mcp-development.md" if has_mcp_server else "__skip_mcp_dev__.md"}}`

**Step 1: Write the development guide**

This goes in `docs/` in the generated project — not `.claude/rules/` — so it doesn't bloat agent context every session. Agents can read it on demand when working on MCP tools.

The `template/docs/` directory already exists (it has `benchmarks-howto.md`, `README.md`, etc.), so we just add a conditionally-named file inside it. Plain markdown, no `.jinja` suffix needed:

```markdown
# MCP Server Development Guide

## Architecture

The MCP server (`src/server.rs`) is a presentation layer for the core library — the same relationship the CLI commands have. Both are interfaces; the core library is the source of truth.

```
┌─────────────────┐     ┌─────────────────┐
│   CLI commands   │     │   MCP server    │
│  (src/commands/) │     │  (src/server.rs)│
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────┐   ┌──────────┘
                 ▼   ▼
          ┌──────────────┐
          │  core library │
          │ (project-core)│
          └──────────────┘
```

## Adding a New Tool

1. **Define parameters** — Create a struct deriving `Deserialize` + `JsonSchema`:

   ```rust
   #[derive(Debug, serde::Deserialize, schemars::JsonSchema)]
   pub struct MyToolParams {
       /// Description shown to AI clients
       pub required_field: String,
       #[serde(default)]
       pub optional_field: Option<i32>,
   }
   ```

2. **Add the tool method** — Inside the `#[tool_router] impl ProjectServer` block:

   ```rust
   #[tool(description = "One-line description of what this tool does")]
   async fn my_tool(
       &self,
       Parameters(params): Parameters<MyToolParams>,
   ) -> Result<CallToolResult, McpError> {
       // Call core library functions here
       let result = some_core_function(params.required_field)?;
       let json = serde_json::to_string_pretty(&result)
           .map_err(|e| McpError::internal_error(format!("serialization error: {e}"), None))?;
       Ok(CallToolResult::success(vec![Content::text(json)]))
   }
   ```

3. That's it. The `#[tool_router]` macro auto-registers the method.

## Error Conversion Pattern

Map core library errors to MCP errors at the tool handler boundary:

| Core error | MCP error |
|------------|-----------|
| Item not found | `McpError::resource_not_found(msg, None)` |
| Bad input | `McpError::invalid_params(msg, None)` |
| Internal failure | `McpError::internal_error(msg, None)` |
| Serialization | `McpError::internal_error(format!("serialization error: {e}"), None)` |

## Important Constraints

- **Never write to stdout** from tool methods — stdout is the MCP transport. Use `tracing::info!()` or `eprintln!()` for diagnostics.
- **Delegate to core** — tool methods are thin wrappers. Business logic belongs in the core library crate.
- **Return JSON for structured data** — Use `serde_json::to_string_pretty()` and `Content::text()`.
- **Parameter docs matter** — `schemars` generates JSON Schema from doc comments and `#[schemars(description)]` attributes. AI clients use these to understand tool contracts.

## Testing MCP Tools

Use the MCP Inspector to test tools interactively:

```bash
npx @modelcontextprotocol/inspector cargo run -- serve
```

## Client Configuration

Add to Claude Code `settings.json` or `.mcp.json`:

```json
{
  "mcpServers": {
    "my-project": {
      "command": "cargo",
      "args": ["run", "--", "serve"]
    }
  }
}
```
```

**Step 2: Commit**

```bash
git add template/
git commit -m "$(cat <<'EOF'
feat(template): add MCP development guide in docs/

Placed in docs/ rather than .claude/rules/ to avoid bloating agent
context. Covers tool addition, error conversion, testing with MCP
Inspector, and client configuration.
EOF
)"
```

---

## Task 9: Add conditional file tests for MCP server

**Files:**
- Modify: `test/conditional_files.bats`

**Step 1: Add MCP server conditional file tests**

Append to `test/conditional_files.bats` before the "Template Sanity Checks" section:

```bash
# =============================================================================
# MCP Server
# =============================================================================

@test "has_mcp_server=true includes server.rs and serve command" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-mcp-on" "standard.yml" \
        "has_mcp_server=true")

    assert_file_in_project "$output_dir" "crates/test-standard/src/server.rs"
    assert_file_in_project "$output_dir" "crates/test-standard/src/commands/serve.rs"
    assert_file_contains "$output_dir" "crates/test-standard/Cargo.toml" 'rmcp'
    assert_file_contains "$output_dir" "crates/test-standard/Cargo.toml" 'schemars'
    assert_file_contains "$output_dir" "crates/test-standard/Cargo.toml" 'tokio'
}

@test "has_mcp_server=false excludes server.rs and serve command" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-mcp-off" "standard.yml" \
        "has_mcp_server=false")

    assert_no_file_in_project "$output_dir" "crates/test-standard/src/server.rs"
    assert_no_file_in_project "$output_dir" "crates/test-standard/src/commands/serve.rs"
    assert_file_not_contains "$output_dir" "crates/test-standard/Cargo.toml" 'rmcp'
}

@test "has_mcp_server=true includes MCP development guide" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-mcp-guide" "standard.yml" \
        "has_mcp_server=true")

    assert_file_in_project "$output_dir" "docs/mcp-development.md"
}

@test "has_mcp_server=false excludes MCP development guide" {
    local output_dir
    output_dir=$(generate_project_with_data "cond-mcp-guide-off" "standard.yml" \
        "has_mcp_server=false")

    assert_no_file_in_project "$output_dir" "docs/mcp-development.md"
}
```

**Step 2: Run the conditional file tests**

```bash
bats test/conditional_files.bats
```

Expected: All tests pass, including the 4 new MCP tests.

**Step 3: Commit**

```bash
git add test/conditional_files.bats
git commit -m "$(cat <<'EOF'
test: add conditional file tests for MCP server scaffolding

Verifies server.rs, serve.rs, Cargo.toml deps, and agent rule file
are included/excluded based on has_mcp_server flag.
EOF
)"
```

---

## Task 10: Full build verification — standard preset with MCP

**Files:** None (test-only)

**Step 1: Generate a standard project with MCP enabled**

```bash
rm -rf target/template-tests/mcp-build-test
copier copy --trust --defaults \
  --data-file scripts/presets/standard.yml \
  --data has_mcp_server=true \
  . target/template-tests/mcp-build-test
```

**Step 2: Run clippy**

```bash
cd target/template-tests/mcp-build-test
cargo clippy --all-targets --all-features --message-format=short -- -D warnings
```

Expected: Clean (0 warnings, 0 errors)

**Step 3: Run tests**

```bash
cargo nextest run
```

Expected: All existing tests pass. The `serve` command won't have integration tests yet (testing an MCP server over stdio requires a client harness), but clippy + existing CLI tests must be clean.

**Step 4: Verify the serve subcommand appears in help**

```bash
cargo run -- --help 2>/dev/null | grep -i serve
```

Expected: Output contains "serve" subcommand with description.

**Step 5: Also verify minimal preset still works without MCP**

```bash
rm -rf target/template-tests/mcp-minimal-check
copier copy --trust --defaults \
  --data-file scripts/presets/minimal.yml \
  . target/template-tests/mcp-minimal-check
cd target/template-tests/mcp-minimal-check
cargo clippy --all-targets --all-features --message-format=short -- -D warnings
cargo nextest run
```

Expected: Clean build, no MCP artifacts.

**Step 6: Fix any issues**

If clippy or tests fail, fix the template files and re-run. Common issues:
- Missing `use` imports (check that `serde` is available — it's already a dep)
- Nursery lint warnings on generated code (add targeted `#[allow()]` attributes)
- Module declaration ordering

No commit from this task — it's verification only.

---

## Task 11: Update consolidated status and handoff

**Files:**
- Modify: `.claude/plans/consolidated-status.md`
- Create: `.handoffs/2026-01-27-HHMM-mcp-server-scaffolding.md`

**Step 1: Move Phase 7 to completed in consolidated-status.md**

Update the "Remaining Work" → Phase 7 section to "Completed Work" with a summary:

```markdown
### Phase 7: MCP Server Scaffolding ✅
- `has_mcp_server` flag (default: false, gated on `has_cli`)
- `needs_tokio` computed variable consolidating async runtime needs
- `serve` subcommand in CLI binary routing to `ProjectServer`
- `server.rs` with `#[tool_router]`/`#[tool_handler]` scaffold (rmcp 0.14)
- Example tool with `schemars` parameter struct (conditional on `has_core_library`)
- `docs/mcp-development.md` guide (not in `.claude/rules/` — avoids context bloat)
- 4 conditional file tests + full build verification

**Post-release milestone:** OAuth-based MCP authentication (see rmcp `auth` feature + `cimd_auth_streamhttp` example)
```

**Step 2: Write handoff document**

Create `.handoffs/2026-01-27-HHMM-mcp-server-scaffolding.md` following the established format.

**Step 3: Commit**

```bash
git add .claude/plans/consolidated-status.md .handoffs/
git commit -m "$(cat <<'EOF'
docs: update consolidated status and add MCP server handoff

Phase 7 complete. Notes OAuth as post-release milestone.
EOF
)"
```

---

## Post-Release Milestone: OAuth MCP Authentication

Not part of this branch. Noted here for future planning:

- The `rmcp` crate supports `auth` feature with OAuth2 5.0
- Reference impl: `examples/servers/src/cimd_auth_streamhttp.rs` in the rust-sdk repo
- Would add a `mcp_auth` flag gating OAuth2 integration
- Requires `transport-streamable-http-server` feature (adds `axum` dep)
- Separate ADR needed for auth flow design

---

## Summary of All Files Touched

| Action | File |
|--------|------|
| Modify | `copier.yaml` |
| Modify | `scripts/presets/minimal.yml` |
| Modify | `scripts/presets/standard.yml` |
| Modify | `scripts/presets/standard-otel.yml` |
| Modify | `scripts/presets/full.yml` |
| Modify | `bin/claylo-rs` |
| Modify | `template/crates/{{cli}}/Cargo.toml.jinja` |
| Modify | `template/crates/{{cli}}/src/main.rs.jinja` |
| Modify | `template/crates/{{cli}}/src/lib.rs.jinja` |
| Rename+Modify | `template/crates/{{cli}}/src/commands/mod.rs` → `mod.rs.jinja` |
| Create | `template/crates/{{cli}}/src/commands/{{"serve.rs" if ... else "__skip_serve__.rs"}}` |
| Create | `template/crates/{{cli}}/src/{{"server.rs" if ... else "__skip_mcp_server__.rs"}}.jinja` |
| Create | `template/docs/{{"mcp-development.md" if ... else "__skip_mcp_dev__.md"}}` |
| Modify | `test/conditional_files.bats` |
| Modify | `.claude/plans/consolidated-status.md` |
| Create | `.handoffs/2026-01-27-HHMM-mcp-server-scaffolding.md` |
