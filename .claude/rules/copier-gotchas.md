# Copier Behavioral Gotchas

Hard-won lessons from template development. These are copier behaviors that are correct but non-obvious.

## Jinja Whitespace Control

`{%- tag %}` strips **preceding** whitespace/newline. `{% tag -%}` strips **following** whitespace/newline.

- Use `{%- tag %}` for clean output (the common case)
- Avoid `{% tag -%}` — it strips too aggressively and eats the next line's indentation
- Inside block scalars, whitespace control determines whether blank lines appear between sections

## Computed Variables

Variables with `when: false` are **computed once** by copier's formula engine.

- **Never** pass computed variables via `--data` — copier skips the formula and uses the raw value
- **Never** include computed variables in preset `--data-file` YAML — same problem
- Examples: `project_name`, `crate_name`, `copyright_year`, `needs_tokio`, `npm`
- Preset files should only contain user-facing `has_*` flags and explicit choices

## Copier Source Path

Copier expects the **repo root** (where `copier.yaml` lives), not the `template/` subdirectory.

```bash
# Correct
copier copy --trust --defaults /path/to/repo target/output

# Wrong — copier can't find copier.yaml
copier copy --trust --defaults /path/to/repo/template target/output
```

The `_subdirectory: template` directive in copier.yaml tells copier where the template files are.

## File Permissions

Copier preserves source file permissions. If a generated file needs to be executable:

```bash
chmod +x template/path/to/script.sh.jinja
```

Do this on the `.jinja` source file — the permission carries through to the output.

## Answers File Templates

- `_copier_conf.data` — the raw answers dict (use in `_copier_answers` templates)
- `_copier_answers` — the rendered answers file (`.repo.yml`)
- In the answers file template, iterate `_copier_conf.data` to emit all answers

## Boolean Defaults and `--defaults`

`--defaults` without `--data-file` uses copier.yaml defaults. If a boolean flag defaults to `false` (or to a Jinja expression that evaluates to `false`), it will be falsy. Always pair `--defaults` with `--data-file` when testing non-default configurations.

## Conflict Handling

`--conflict inline` writes conflict markers directly into files instead of creating `.rej` sidecar files. This is the preferred mode for `copier update`.

Copier skips files listed in `.gitignore` during conflict resolution — if a generated file is gitignored, conflicts won't be detected.

## `{% raw %}` Blocks

`{% raw %}` blocks **cannot be nested**. If a template file contains `{% raw %}...{% endraw %}` and you wrap the whole file in another `{% raw %}`, the inner `{% endraw %}` terminates the outer block.

For GitHub Actions workflows that need both Jinja variables and `${{ }}` expressions, use workflow-level `env:` blocks with the project name to avoid Jinja conflicts:

```yaml
env:
  PROJECT: {{ project_name }}
```

Then reference `${{ env.PROJECT }}` instead of hard-coding the name.
