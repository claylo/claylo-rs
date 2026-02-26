# Wrapper Precedence Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the `bin/claylo-rs` wrapper so user data-file preferences are respected, computed variables are left to copier, and preset flags only contain values that differ between presets.

**Architecture:** The wrapper merges three layers (preset → data-file → CLI flags) into a bash associative array, then emits all values as `--data` flags. No `--data-file` is sent to copier. Computed variables (`has_xtask`, `needs_tokio`) are never emitted — copier evaluates their formulas.

**Tech Stack:** Bash 4+ (associative arrays), copier, bats (testing)

---

## Precedence Model

```
CLI flags > data-file > preset > copier.yaml defaults
  (highest)                         (lowest)
```

## Category-4 Variables (the only ones kept in presets)

| Variable | full | standard | minimal |
|----------|------|----------|---------|
| `has_core_library` | true | true | false |
| `has_config` | true | true | false |
| `has_jsonl_logging` | true | true | false |
| `has_opentelemetry` | true | false | false |
| `has_benchmarks` | true | false | false |
| `has_gungraun` | false | — | — |
| `has_site` | true | true | false |
| `has_community_files` | true | false | false |
| `has_yamlfmt` | true | false | false |
| `has_yamllint` | true | false | false |
| `has_editorconfig` | true | false | false |
| `has_env_files` | true | false | false |
| `has_md` | true | true | false |
| `has_md_strict` | false | false | — |
| `has_skill_markdown_authoring` | true | true | false |
| `has_releases` | true | true | false |

"—" means the variable's `when` condition is false for that preset, so it's not set (copier uses its default).

---

### Task 1: Add `parse_yaml_into` function

**Files:**
- Modify: `bin/claylo-rs` (insert after `find_defaults_file`, before ALIAS_MAP ~line 73)

**Step 1: Add the function**

Insert after the `find_defaults_file` function (after line 72):

```bash
# ---------------------------------------------------------------------------
# Parse a flat YAML file into an associative array
# ---------------------------------------------------------------------------
# Handles: key: value, key: "value", key: 'value'
# Skips: comments, blank lines, copier internal keys (_prefix)
parse_yaml_into() {
  local -n _yaml_map=$1
  local file="$2"
  local line key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
    # Skip copier internal keys
    [[ "$line" =~ ^[[:space:]]*_ ]] && continue
    # Parse key: value
    if [[ "$line" =~ ^([a-zA-Z][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.*) ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Trim trailing whitespace and inline comments
      value="${value%%[[:space:]]#*}"
      value="${value%"${value##*[![:space:]]}"}"
      # Strip surrounding quotes
      if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
        value="${BASH_REMATCH[1]}"
      fi
      _yaml_map["$key"]="$value"
    fi
  done < "$file"
}
```

**Step 2: Verify syntax**

Run: `bash -n bin/claylo-rs`
Expected: no output (clean parse)

**Step 3: Commit**

```bash
git add bin/claylo-rs
git commit -m "feat(wrapper): add parse_yaml_into for data-file merging"
```

---

### Task 2: Rewrite `get_preset_flags` → `load_preset_flags`

**Files:**
- Modify: `bin/claylo-rs:321-443` (replace entire function)

**Step 1: Replace `get_preset_flags` with `load_preset_flags`**

Replace lines 316-443 (from the comment block through `# END GENERATED`) with:

```bash
# ---------------------------------------------------------------------------
# Load preset-specific feature flags into an associative array
#
# Only includes variables that DIFFER between presets (category 4).
# Computed vars (has_xtask, needs_tokio) are left to copier formulas.
# Choice vars (site_deploy, site_package_manager, lint_level) are left
# to copier defaults or user data-file.
# Redundant vars (same across all presets) are left to copier defaults.
# ---------------------------------------------------------------------------
load_preset_flags() {
  local preset="$1"
  local -n _pmap=$2

  case "$preset" in
    full)
      _pmap[has_core_library]=true
      _pmap[has_config]=true
      _pmap[has_jsonl_logging]=true
      _pmap[has_opentelemetry]=true
      _pmap[has_benchmarks]=true
      _pmap[has_gungraun]=false
      _pmap[has_site]=true
      _pmap[has_community_files]=true
      _pmap[has_yamlfmt]=true
      _pmap[has_yamllint]=true
      _pmap[has_editorconfig]=true
      _pmap[has_env_files]=true
      _pmap[has_md]=true
      _pmap[has_md_strict]=false
      _pmap[has_skill_markdown_authoring]=true
      _pmap[has_releases]=true
      ;;
    minimal)
      _pmap[has_core_library]=false
      _pmap[has_config]=false
      _pmap[has_jsonl_logging]=false
      _pmap[has_opentelemetry]=false
      _pmap[has_benchmarks]=false
      _pmap[has_site]=false
      _pmap[has_community_files]=false
      _pmap[has_yamlfmt]=false
      _pmap[has_yamllint]=false
      _pmap[has_editorconfig]=false
      _pmap[has_env_files]=false
      _pmap[has_md]=false
      _pmap[has_skill_markdown_authoring]=false
      _pmap[has_releases]=false
      ;;
    standard)
      _pmap[has_core_library]=true
      _pmap[has_config]=true
      _pmap[has_jsonl_logging]=true
      _pmap[has_opentelemetry]=false
      _pmap[has_benchmarks]=false
      _pmap[has_site]=true
      _pmap[has_community_files]=false
      _pmap[has_yamlfmt]=false
      _pmap[has_yamllint]=false
      _pmap[has_editorconfig]=false
      _pmap[has_env_files]=false
      _pmap[has_md]=true
      _pmap[has_md_strict]=false
      _pmap[has_skill_markdown_authoring]=true
      _pmap[has_releases]=true
      ;;
  esac
}
```

**Step 2: Verify syntax**

Run: `bash -n bin/claylo-rs`
Expected: no output (clean parse)

**Step 3: Commit**

```bash
git add bin/claylo-rs
git commit -m "refactor(wrapper): slim preset flags to category-4 only

Remove computed vars (has_xtask), choice vars (site_deploy,
site_package_manager, lint_level), and redundant booleans that
match copier.yaml defaults from preset flags."
```

---

### Task 3: Update `parse_features` to use associative array

**Files:**
- Modify: `bin/claylo-rs:173-214` (the `parse_features` function)

**Step 1: Change the function signature and output**

Replace the `parse_features` function with:

```bash
parse_features() {
  local input="$1"
  local -n _fmap=$2  # nameref to caller's associative array

  [[ -z "$input" ]] && return 0

  # First character must be + or -
  if [[ "${input:0:1}" != "+" && "${input:0:1}" != "-" ]]; then
    echo "Error: feature string must start with + or -: ${input}" >&2
    exit 1
  fi

  # Insert a newline before each + or - so we can split on them
  local delimited
  delimited=$(printf '%s' "$input" | sed 's/[+-]/\n&/g')

  while IFS= read -r token; do
    [[ -z "$token" ]] && continue
    local prefix="${token:0:1}"
    local name="${token:1}"

    if [[ -z "$name" ]]; then
      echo "Error: empty feature name after '${prefix}'" >&2
      exit 1
    fi

    if [[ -z "${ALIAS_MAP[$name]+x}" ]]; then
      echo "Error: unknown feature '${name}'" >&2
      echo "" >&2
      echo "Valid features:" >&2
      echo "$SORTED_ALIASES" | paste - - - - | column -t >&2
      exit 1
    fi

    local var="${ALIAS_MAP[$name]}"
    if [[ "$prefix" == "+" ]]; then
      _fmap["$var"]=true
    else
      _fmap["$var"]=false
    fi
  done <<< "$delimited"
}
```

The only change: nameref is now an associative array (`_fmap["$var"]=true`) instead of an indexed array (`out_arr+=("--data" ...)`).

**Step 2: Verify syntax**

Run: `bash -n bin/claylo-rs`
Expected: no output (clean parse)

**Step 3: Commit**

```bash
git add bin/claylo-rs
git commit -m "refactor(wrapper): parse_features populates associative array"
```

---

### Task 4: Rewrite `main()` — arg parsing and `new` command

**Files:**
- Modify: `bin/claylo-rs:478-648` (main function, arg parsing through new-command block)

**Step 1: Change local variable declarations**

Replace lines 492-494:
```bash
  local feature_strings=()
  local data_args=()
  local extra_data=()
```

With:
```bash
  local feature_strings=()
  declare -A feature_map=()
  declare -A extra_data_map=()
```

**Step 2: Change the `--data` case in the arg parser**

Replace lines 550-553:
```bash
      --data)
        [[ $# -lt 2 ]] && { echo "Error: --data requires a key=value" >&2; exit 1; }
        extra_data+=("--data" "$2")
        shift 2
        ;;
```

With:
```bash
      --data)
        [[ $# -lt 2 ]] && { echo "Error: --data requires a key=value" >&2; exit 1; }
        if [[ "$2" =~ ^([^=]+)=(.*)$ ]]; then
          extra_data_map["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        else
          echo "Error: --data value must be key=value format: $2" >&2
          exit 1
        fi
        shift 2
        ;;
```

**Step 3: Change feature string parsing**

Replace lines 592-595:
```bash
  # Parse all feature strings
  for fs in "${feature_strings[@]}"; do
    parse_features "$fs" data_args
  done
```

With:
```bash
  # Parse all feature strings into associative array
  for fs in "${feature_strings[@]}"; do
    parse_features "$fs" feature_map
  done
```

**Step 4: Rewrite the `new` command block**

Replace lines 617-648 (from the `# Build the copier command` comment through the end of the `new` block) with:

```bash
  # ---------------------------------------------------------------------------
  # Build the copier command
  # ---------------------------------------------------------------------------
  # Precedence (highest to lowest):
  #   1. CLI flags (--lint, --hook, +features, --data key=value)
  #   2. Data-file (~/.claylo-rs.defaults.yaml or --data-file path)
  #   3. Preset flags (category-4 vars that differ between presets)
  #   4. copier.yaml defaults (handled by copier itself)
  #
  # Layers 1-3 are merged here. No --data-file is sent to copier.
  # Computed vars (has_xtask, needs_tokio) are never emitted — copier
  # evaluates their formulas from copier.yaml.
  # ---------------------------------------------------------------------------
  local -a cmd=()

  if [[ "$command" == "new" ]]; then
    [[ -z "$dest" ]] && { echo "Error: destination path required" >&2; echo "Usage: claylo-rs new <dest>" >&2; exit 1; }

    local project_name
    project_name="$(basename "$dest")"

    # --- Merge layers into associative array ---
    declare -A merged=()

    # Layer 1 (lowest): preset flags
    load_preset_flags "$preset" merged

    # Layer 2: data-file overwrites preset
    if [[ -n "$data_file" ]]; then
      parse_yaml_into merged "$data_file"
    fi

    # Layer 3: CLI named flags overwrite data-file
    [[ -n "$owner" ]] && merged[owner]="$owner"
    [[ -n "$copyright" ]] && merged[copyright_name]="$copyright"
    [[ -n "$desc" ]] && merged[project_description]="$desc"
    [[ -n "$lint" ]] && merged[lint_level]="$lint"
    [[ -n "$hook" ]] && merged[hook_system]="$hook"

    # Layer 4: +/- feature flags overwrite everything so far
    for key in "${!feature_map[@]}"; do
      merged["$key"]="${feature_map[$key]}"
    done

    # Layer 5 (highest): --data key=value overrides all
    for key in "${!extra_data_map[@]}"; do
      merged["$key"]="${extra_data_map[$key]}"
    done

    # Always set identity fields
    merged[project_name]="$project_name"
    merged[preset]="$preset"

    # --- Build copier command ---
    cmd=(copier copy --prereleases)
    [[ "$use_defaults" == true ]] && cmd+=(--defaults)
    [[ "$dry_run" == true ]] && cmd+=(--pretend)
    [[ -n "$vcs_ref" ]] && cmd+=(--vcs-ref "$vcs_ref")

    # Emit merged data (sorted for deterministic output)
    local key
    while IFS= read -r key; do
      cmd+=(--data "${key}=${merged[$key]}")
    done < <(printf '%s\n' "${!merged[@]}" | sort)

    cmd+=("$template_src" "$dest")
```

**Step 5: Verify syntax**

Run: `bash -n bin/claylo-rs`
Expected: no output (clean parse)

**Step 6: Commit**

```bash
git add bin/claylo-rs
git commit -m "feat(wrapper): merge-based precedence for new command

Data-file values now override preset flags. CLI flags override both.
Computed vars left to copier formulas. No --data-file sent to copier."
```

---

### Task 5: Rewrite `main()` — `update` command

**Files:**
- Modify: `bin/claylo-rs` (the `elif [[ "$command" == "update" ]]` block)

**Step 1: Replace the update block**

Replace the entire `elif` block (from `elif [[ "$command" == "update" ]]` through `cmd+=("$dest")`) with:

```bash
  elif [[ "$command" == "update" ]]; then
    [[ -z "$dest" ]] && dest="."

    # --- Merge layers into associative array ---
    declare -A merged=()

    # Layer 1 (lowest): preset flags — only if explicitly requested
    if [[ "$preset_set" == true ]]; then
      load_preset_flags "$preset" merged
      merged[preset]="$preset"
    fi

    # Layer 2: data-file overwrites preset
    if [[ -n "$data_file" ]]; then
      parse_yaml_into merged "$data_file"
    fi

    # Layer 3: CLI named flags
    [[ -n "$owner" ]] && merged[owner]="$owner"
    [[ -n "$copyright" ]] && merged[copyright_name]="$copyright"
    [[ -n "$desc" ]] && merged[project_description]="$desc"
    [[ -n "$lint" ]] && merged[lint_level]="$lint"
    [[ -n "$hook" ]] && merged[hook_system]="$hook"

    # Layer 4: +/- feature flags
    for key in "${!feature_map[@]}"; do
      merged["$key"]="${feature_map[$key]}"
    done

    # Layer 5 (highest): --data key=value
    for key in "${!extra_data_map[@]}"; do
      merged["$key"]="${extra_data_map[$key]}"
    done

    # --- Build copier command ---
    cmd=(copier update --prereleases)
    [[ "$use_defaults" == true ]] && cmd+=(--defaults)
    [[ "$dry_run" == true ]] && cmd+=(--pretend)
    [[ -n "$vcs_ref" ]] && cmd+=(--vcs-ref "$vcs_ref")
    cmd+=(--conflict rej)
    cmd+=(--answers-file .repo.yml)

    # Emit merged data (sorted for deterministic output)
    local key
    while IFS= read -r key; do
      cmd+=(--data "${key}=${merged[$key]}")
    done < <(printf '%s\n' "${!merged[@]}" | sort)

    cmd+=("$dest")
  fi
```

**Step 2: Verify syntax**

Run: `bash -n bin/claylo-rs`
Expected: no output (clean parse)

**Step 3: Commit**

```bash
git add bin/claylo-rs
git commit -m "feat(wrapper): merge-based precedence for update command"
```

---

### Task 6: Clean up preset YAML test files

**Files:**
- Modify: `scripts/presets/full.yml:11` (remove `needs_tokio`)
- Modify: `scripts/presets/full.yml` (remove `has_xtask`)
- Modify: `scripts/presets/standard.yml` (remove `has_xtask`)
- Modify: `scripts/presets/minimal.yml` (remove `has_xtask`, remove `site_deploy` since `has_site=false`)

**Step 1: Edit full.yml**

Remove line 11 (`needs_tokio: true`) and line 18 (`has_xtask: true`).

**Step 2: Edit standard.yml**

Remove `has_xtask: true` (line 16).

**Step 3: Edit minimal.yml**

Remove `has_xtask: false` (line 15) and `site_deploy: github_pages` (line 14).

**Step 4: Verify remaining preset files are internally consistent**

Spot-check that remaining values match the category-4 table and copier.yaml defaults.

**Step 5: Commit**

```bash
git add scripts/presets/
git commit -m "fix(presets): remove computed vars from test data files

Remove needs_tokio (computed from has_opentelemetry/has_mcp_server)
and has_xtask (computed from has_cli) from preset YAML files.
Remove site_deploy from minimal where has_site=false."
```

---

### Task 7: Dry-run verification

**Step 1: Test data-file precedence with `new`**

Create a temp defaults file and verify the wrapper respects it:

```bash
cat > /tmp/test-defaults.yaml <<'EOF'
site_package_manager: pnpm
site_deploy: cloudflare_github_actions
lint_level: strict
owner: testowner
copyright_name: Test User
EOF

bin/claylo-rs new /tmp/test-precedence \
  --local --dry-run -y \
  --data-file /tmp/test-defaults.yaml \
  --preset standard 2>&1 | head -30
```

Expected in the `Running:` output:
- `--data site_package_manager=pnpm` (from data-file, NOT `npm`)
- `--data site_deploy=cloudflare_github_actions` (from data-file, NOT `github_pages`)
- `--data lint_level=strict` (from data-file)
- No `--data-file` flag
- No `--data has_xtask=...` (computed, not emitted)

**Step 2: Test CLI overrides beat data-file**

```bash
bin/claylo-rs new /tmp/test-cli-override \
  --local --dry-run -y \
  --data-file /tmp/test-defaults.yaml \
  --preset standard \
  --lint relaxed 2>&1 | head -30
```

Expected: `--data lint_level=relaxed` (CLI beats data-file's `strict`)

**Step 3: Test +/- feature flags beat preset**

```bash
bin/claylo-rs new /tmp/test-features \
  --local --dry-run -y \
  --preset minimal +core+config+releases 2>&1 | head -30
```

Expected:
- `--data has_core_library=true` (feature flag overrides minimal's `false`)
- `--data has_config=true` (same)
- `--data has_releases=true` (same)
- No `has_xtask` in output (computed by copier → will be true since has_cli=true)

**Step 4: Clean up**

```bash
rm -f /tmp/test-defaults.yaml
rm -rf /tmp/test-precedence /tmp/test-cli-override /tmp/test-features
```

---

### Task 8: Run existing bats tests

**Step 1: Run fast conditional file tests**

```bash
just test-fast
```

Expected: all tests pass (these don't use the wrapper, but verify template integrity)

**Step 2: Run full preset tests**

```bash
just test-presets
```

Expected: all tests pass. The preset YAML files still have all the explicit values tests need.

**Step 3: If any test fails, investigate**

Check whether the test relied on a variable that was removed from `get_preset_flags()`. The preset YAML files (used by tests) are kept exhaustive, so tests should be unaffected. If a test fails, it's likely a YAML file edit error from Task 6.

**Step 4: Commit test verification**

No commit needed — this is verification only.

---

## Bugs Fixed

1. `site_package_manager` / `site_deploy` from data-file ignored (precedence)
2. `has_xtask=false` hardcoded in minimal preset (computed var override)
3. `has_attestations=true` forced for minimal (copier.yaml formula gives false)
4. `lint_level=strict` forced for all presets (now respects data-file, falls back to copier.yaml conditional)
