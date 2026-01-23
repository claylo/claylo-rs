# Rust Development Guidelines

## Philosophy: Check First, Then Code

Your base model may be anchored to older Rust patterns. The MCP server and shell commands give you a live truth oracle. Use them.

**Before writing code**: Run `workspace-info` via MCP to understand the crate structure.  
**After writing code**: Run clippy and tests before presenting.

---

## Commands

Use these exact commands (derived from project justfile):

| Task | Command |
|------|---------|
| Format | `cargo fmt --all` |
| Lint | `cargo clippy --all-targets --all-features --message-format=short -- -D warnings` |
| Auto-fix | `cargo clippy --fix --allow-dirty --allow-staged -- -W clippy::all` |
| Tests | `cargo nextest run` |
| Doc tests | `cargo test --doc` |
| Security | `cargo deny check` |
| Build release | `cargo build -p draftkit --release` |

**For tests, always use `cargo nextest run`** — it's 10x faster than `cargo test`.

---

## MCP Server: rust-mcp-server

**Crate**: [Vaiz/rust-mcp-server](https://github.com/Vaiz/rust-mcp-server)

Useful for:
- `workspace-info` — understand crate structure
- `cargo-clippy` with `all_targets: true`, `all_features: true`, `warnings_as_errors: true`
- `cargo-fmt`, `cargo-deny-check`

**Not available via MCP**: nextest, llvm-cov, bench, xtask — use shell commands.

---

## Project Configuration

```toml
edition = "2024"
rust-version = "1.88.0"
unsafe_code = "deny"
clippy: all = "warn", nursery = "warn"
```

---

## Edition 2024 Patterns (Mandatory)

```rust
// Unsafe attributes
#[unsafe(no_mangle)]  // not #[no_mangle]

// Extern blocks
extern "C" { }        // not extern { }

// Unsafe in unsafe fns
unsafe fn foo(ptr: *const u8) {
    unsafe { let _ = *ptr; }  // explicit block required
}
```

---

## Patterns to Avoid

| Outdated | Modern |
|----------|--------|
| `extern { }` | `extern "C" { }` |
| `#[no_mangle]` | `#[unsafe(no_mangle)]` |
| `.clone()` on Copy types | Just copy |
| `&String` / `&Vec<T>` / `&PathBuf` / `&Box<T>` | `&str` / `&[T]` / `&Path` / `&T` |
| `Box<dyn Error>` | `anyhow::Result` or `thiserror` |
| `.replace('a', "x").replace('b', "x")` | `.replace(['a', 'b'], "x")` |
| `fn foo() -> T { constant }` | `const fn foo() -> T { constant }` |
| `std::mem::transmute(x)` | `std::mem::transmute::<Src, Dst>(x)` |
| `match opt { Some(x) => x, None => return }` | `let Some(x) = opt else { return };` |

---

## Code Discipline

- Only generate code that has immediate callers
- Read existing code before adding abstractions
- Unsafe requires `#[allow(unsafe_code)]` + `// SAFETY:` comment

---

## Default Crate Stack

| Purpose | Crate(s) |
|---------|----------|
| CLI | `clap` (derive) + `clap_complete` |
| Errors | `thiserror` (lib) / `anyhow` (bin) |
| Logging | `tracing` + `tracing-subscriber` |
| Serialization | `serde` + `serde_json` |
| Testing | `assert_cmd` + `predicates` + `insta` |
| Async | `tokio` (only when needed) |
| HTTP | `reqwest` (client) / `axum` (server) |
| Paths | `camino` |

---

## When Uncertain

Ask me rather than guessing. Do not invent APIs.
