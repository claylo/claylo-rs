# Updating Projects

Copier tracks what it generated.
When the template improves, your project can follow.


## Contents

- [How Updates Work](#how-updates-work)
- [Single Project Update](#single-project-update)
- [Adding Features](#adding-features)
- [Bulk Updates](#bulk-updates)
- [Conflict Resolution](#conflict-resolution)


## How Updates Work

Copier stores your answers in `.copier-answers.yml`.
When you update, Copier performs a three-way merge:

1. **Base**: The template version you originally generated from
2. **Theirs**: The current template version
3. **Yours**: Your modifications

Your changes stay.
Template improvements land.
Conflicts are marked for manual resolution.


## Single Project Update

From within your project directory:

```bash
claylo-rs update
```

Or specify the path:

```bash
claylo-rs update ./my-tool
```

### Preview First

See what would change without writing files:

```bash
claylo-rs update --dry-run
```


## Adding Features

Add features you skipped initially:

```bash
# Add OpenTelemetry tracing
claylo-rs update +otel

# Add MCP server scaffolding
claylo-rs update +mcp

# Add benchmarks
claylo-rs update +bench
```

Remove features you no longer need:

```bash
# Remove site placeholder
claylo-rs update -site

# Remove community files
claylo-rs update -community
```


## Bulk Updates

Scan multiple projects for available updates:

```bash
# From the template repository
./scripts/update-projects.sh ~/my-projects
```

Apply updates (creates branches for review):

```bash
./scripts/update-projects.sh -u ~/my-projects
```

Filter to projects generated from this template:

```bash
./scripts/update-projects.sh -f claylo-rs ~/my-projects
```


## Conflict Resolution

When Copier can't merge automatically, it marks conflicts:

```
<<<<<<< HEAD
your version
=======
template version
>>>>>>> template
```

Resolve these manually, then commit.

### Common Conflicts

**Cargo.toml dependencies**: Template adds new dependencies; you've added your own.
Resolution: Keep both.

**Workflow files**: Template updates CI; you've customized it.
Resolution: Merge the structural changes, keep your customizations.

**README.md**: Template updates boilerplate; you've rewritten it.
Resolution: Usually keep yours, adopt any new patterns you like.

### Avoiding Conflicts

Keep customizations in separate files when possible.
The template is designed with extension points:

- Add commands in `crates/<project>/src/commands/`
- Add library code in `crates/<project>-core/src/`
- Add tests in `tests/`

Files the template doesn't touch won't conflict.
