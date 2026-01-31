# Post-Generation Tasks

This document describes the challenges with Copier's `_tasks` feature and how `claylo-rs` handles post-generation setup.

## Copier Task Design Choices

Copier's `_tasks` feature has several constraints that limit flexibility:

### 1. Tasks are Configuration, Not Data

The `--data` and `--data-file` CLI options only affect **question answers**, not **template settings**. Settings like `_tasks`, `_exclude`, and `_subdirectory` are read exclusively from `copier.yaml` and its `!include` files.

This means you cannot:
- Override `_tasks` at runtime via `--data _tasks='[]'`
- Pass a custom tasks file via `--data-file`
- Conditionally swap task files based on user input

### 2. `!include` is Evaluated at YAML Load Time

Copier's `!include` directive is processed during YAML parsing, before Jinja rendering. This means:

```yaml
# This does NOT work - Jinja isn't evaluated yet
!include {{ custom_tasks_file }}
```

### 3. Multi-Document Overrides are All-or-Nothing

While later YAML documents can override `_tasks`, this requires:
- Separate `copier-*.yaml` files for each variant
- Duplicating shared configuration or complex include structures

### 4. `when:` Conditions Work, But...

You can add `when:` conditions to individual tasks:

```yaml
_tasks:
  - command: git init
    when: "{{ run_tasks and _copier_operation == 'copy' }}"
```

This requires:
- Adding a question variable (`run_tasks`) that users must answer
- Every task needing the condition (verbose, error-prone)
- No support for truly custom task sequences

## The Bootstrap Approach

Instead of fighting Copier's design decisions, `claylo-rs` uses `just bootstrap` for flexible post-generation setup:

### Standard Bootstrap

The generated `.justfile` includes a `bootstrap` recipe that:
1. Checks Rust version against MSRV
2. Installs git hooks (if configured)
3. Builds the project
4. Generates shell completions and man pages (if xtask enabled)

### Custom Bootstrap Hook

For users who need different setup behavior, `bootstrap` searches for a `.claylo-rs.bootstrap.sh` file by walking up the directory tree from the current directory to `/`. This mirrors how the `claylo-rs` wrapper discovers `.claylo-rs.defaults.yaml`.

**Search order example** (project at `~/source/work-repos/my-project`):
1. `~/source/work-repos/my-project/.claylo-rs.bootstrap.sh`
2. `~/source/work-repos/.claylo-rs.bootstrap.sh`
3. `~/source/.claylo-rs.bootstrap.sh`
4. `~/.claylo-rs.bootstrap.sh`
5. `/.claylo-rs.bootstrap.sh`

The first file found is sourced; the search stops there.

### Real-World Scenario: Shared Team Defaults

Suppose you organize repositories by context:

```
~/source/
├── work-repos/
│   ├── .claylo-rs.defaults.yaml    # shared copier answers
│   ├── .claylo-rs.bootstrap.sh     # shared bootstrap customization
│   ├── project-alpha/
│   └── project-beta/
├── personal/
│   ├── .claylo-rs.defaults.yaml    # shared copier answers
│   ├── .claylo-rs.bootstrap.sh     # shared bootstrap customization
│   ├── new-idea/
│   └── awesome-oss-project/
└── client-repos/
    └── client-project/
```

- Projects under `work-repos/` automatically pick up your team's bootstrap hook
- Projects under `client-repos/` use standard bootstrap behavior
- Projects under `personal/` pick up your preferred behavior for your personal stuff
- Individual projects can override by adding their own `.claylo-rs.bootstrap.sh`

### Hook Variables and Functions

The bootstrap hook is **sourced** (not executed), so it can set variables and define functions that the bootstrap recipe uses:

| Variable/Function | Default | Purpose |
|-------------------|---------|---------|
| `SKIP_HOOK_INSTALL` | `false` | Set to `true` to skip git hook installation |
| `post_bootstrap()` | no-op | Function called after standard bootstrap steps complete |

You can write your `.claylo-rs.bootstrap.sh` to perform actions within the `post_bootstrap()` function directly,
or you can point to another script.

Example `.claylo-rs.bootstrap.sh`:

```bash
# Skip default hook installation - we use our own
SKIP_HOOK_INSTALL=true

# Custom post-bootstrap step
post_bootstrap() {
    echo "Running team-specific setup..."
    ./scripts/setup-dev-env.sh
}
```

## Related

- [Copier Tasks Documentation](https://copier.readthedocs.io/en/stable/configuring/#tasks)
- [Development Guide](./development.md)
