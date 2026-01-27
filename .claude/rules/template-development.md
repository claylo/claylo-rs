# Template Development Rules

## The Cardinal Rule

**copier.yaml variables are user-facing prompts.** Every variable you add will be shown to developers creating new projects. If they would say "why are you asking me this?", it doesn't belong there.

## Separation of Concerns

| Belongs in copier.yaml | Does NOT belong in copier.yaml |
|------------------------|--------------------------------|
| Project name, description | Test fixtures |
| Feature flags (logging, config, etc.) | CI/CD configuration for the template |
| License, author info | Development tool settings |
| Preset selection | Grafana/monitoring credentials |
| Things every generated project needs | Things only template maintainers need |

## Before Modifying copier.yaml

1. **Ask:** "Is this something a user generating a project needs to configure?"
2. **Ask:** "Would this prompt make sense to someone who's never seen this template?"
3. **Ask:** "Does this follow the existing variable naming pattern?"
4. If any answer is "no" or "I'm not sure" → **stop and discuss with the user**

## Conditional File and Directory Patterns

Copier evaluates Jinja2 expressions in file and directory **names** automatically — no `.jinja` suffix needed for the name itself.

### Conditional directories

```
template/crates/{{project_name if has_cli else "__skip_cli__"}}/
```

Names starting with `__skip_` are excluded via `_exclude` in copier.yaml. The parent directory condition gates all files inside it.

### Conditional files (content has no Jinja)

When a file's **contents** are plain (no template variables), use a conditional filename only:

```
commands/{{"serve.rs" if has_mcp_server else "__skip_serve__.rs"}}
```

No `.jinja` suffix — Copier copies the file as-is.

### Conditional files (content has Jinja)

When a file's **contents** use Jinja template variables, add the `.jinja` suffix so Copier renders the contents:

```
src/{{"server.rs" if has_mcp_server else "__skip_mcp_server__.rs"}}.jinja
```

The `.jinja` suffix is stripped from the output filename (`_templates_suffix: .jinja`).

### Files always present (content has Jinja)

When a file always exists but its contents vary by flags, use `.jinja` suffix only:

```
src/main.rs.jinja        → renders to src/main.rs
src/lib.rs.jinja          → renders to src/lib.rs
Cargo.toml.jinja          → renders to Cargo.toml
```

### Files always present (no Jinja content)

Plain files with no template variables or conditional naming — just use the actual filename:

```
commands/info.rs           → copied verbatim
```

### Key rule

The `.jinja` suffix controls **content rendering**. The `{{...}}` filename controls **file inclusion**. These are orthogonal — a file can use either, both, or neither.

## Structural Changes Require Discussion

These changes are **never** okay to make unilaterally:

- Moving copier.yaml (it lives at repo root, period)
- Splitting config files
- Changing the template/ directory structure
- Adding new top-level directories
- Renaming existing variables
- Changing how presets work

## Testing Infrastructure

Template testing lives in `scripts/`, not in the template itself.

- Test data files: `scripts/*.yml`
- Test runner: `scripts/test-template.sh`
- Test output: `target/template-tests/`

If you need to test OTEL, Grafana, or other integrations, the test harness goes in `scripts/` and uses environment variables or test data files. It does NOT become a copier.yaml variable.

## The "Would This Surprise Someone" Test

Before completing any change, ask: "If the user reviewed this PR without context, would anything make them say 'why did you do it this way?'"

If yes → discuss before proceeding.
