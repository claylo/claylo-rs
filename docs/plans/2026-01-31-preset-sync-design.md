# Preset Sync System Design

**Date:** 2026-01-31

## Problem

Preset configuration is duplicated across multiple files:
- `scripts/presets/*.yml` (source of truth)
- `bin/claylo-rs` (`get_preset_flags()` function)
- `docs/presets.md` (comparison table)
- `test/presets.bats` (hardcoded expectations)

Changing a preset default requires updating 4+ locations manually.

## Solution

A sync script that generates code from the preset YAML files, with runtime `yq` parsing in tests.

## Approach

| Consumer | Method | Reason |
|----------|--------|--------|
| `bin/claylo-rs` | Generated | No runtime dependency, fast startup |
| `copier.yaml` | No change | Defines variables; presets override them |
| `test/*.bats` | Runtime `yq` | Tests already require tooling |
| `docs/presets.md` | Generated | Must stay in sync for users |

## File Structure

### Preset Files

```
scripts/presets/
├── minimal.yml        # Primary preset (appears in docs)
├── standard.yml       # Primary preset
├── full.yml           # Primary preset
└── _standard-otel.yml # Variant (underscore = hidden from comparison)
```

**Convention:** Files prefixed with `_` are variants and don't appear in the comparison table.

### Sync Script

Location: `scripts/sync-presets`

Just recipes:
```just
sync-presets:
    ./scripts/sync-presets

check-presets:
    ./scripts/sync-presets --check
```

## Generated Sections

### Marker Format

Bash:
```bash
# BEGIN GENERATED: section-name
...
# END GENERATED: section-name
```

Markdown:
```markdown
<!-- BEGIN GENERATED: section-name -->
...
<!-- END GENERATED: section-name -->
```

### `bin/claylo-rs`

The `get_preset_flags()` function will be generated:

```bash
# BEGIN GENERATED: get_preset_flags
get_preset_flags() {
  local preset="$1"
  local -n out=$2

  case "$preset" in
    minimal)
      out+=(--data "has_core_library=false")
      out+=(--data "has_config=false")
      # ... flags from minimal.yml
      ;;
    standard)
      # ... flags from standard.yml
      ;;
    full)
      # ... flags from full.yml
      ;;
  esac
}
# END GENERATED: get_preset_flags
```

### `docs/presets.md`

The comparison table will be generated with dynamic columns:

```markdown
<!-- BEGIN GENERATED: preset-comparison -->
| Feature | Minimal | Standard | Full |
|---------|---------|----------|------|
| `has_cli` | ✓ | ✓ | ✓ |
| `has_core_library` | ✗ | ✓ | ✓ |
...
<!-- END GENERATED: preset-comparison -->
```

New primary presets automatically get columns.

## Test Runtime Parsing

### Helper Functions

Add to `test/test_helper.bash`:

```bash
get_preset_names() {
    local presets_dir="${TEMPLATE_DIR}/scripts/presets"
    for f in "$presets_dir"/*.yml; do
        basename "$f" .yml
    done
}

get_preset_value() {
    local preset="$1"
    local key="$2"
    yq -r ".$key // empty" "${TEMPLATE_DIR}/scripts/presets/${preset}.yml"
}
```

### Data-Driven Tests

Tests read expectations from YAML rather than hardcoding:

```bash
@test "full preset: has benchmark infrastructure" {
    if [[ "$(get_preset_value full has_benchmarks)" == "true" ]]; then
        assert_file_in_project "$output_dir" "crates/test-full-core/benches"
    fi
}
```

## Sync Script Behavior

1. **Scan** `scripts/presets/*.yml` for all presets
2. **Separate** primary (no underscore) from variants
3. **Generate** code for each target file
4. **Replace** content between markers
5. **Report** changes
6. **Exit codes:**
   - Default mode: `0` always (applies updates)
   - `--check` mode: `0` if in sync, `1` if drift detected

## Dependencies

- `yq` (Mike Farah's Go version) — already used in `scripts/update-categories.sh`

## Implementation Steps

1. Rename `standard-otel.yml` to `_standard-otel.yml`
2. Add generation markers to `bin/claylo-rs`
3. Add generation markers to `docs/presets.md`
4. Create `scripts/sync-presets`
5. Add helper functions to `test/test_helper.bash`
6. Update `test/presets.bats` to use `yq` for assertions
7. Add `just` recipes
8. Run sync and verify output
