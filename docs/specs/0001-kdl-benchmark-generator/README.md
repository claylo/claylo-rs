# 0001. KDL Benchmark Generator

- Date: 2026-01-06
- Status: :white_check_mark: Active
- ADRs: ../../decisions/0008-three-layer-benchmarking-strategy.md#decision-outcome
- Related: ../../decisions/BENCHMARK-PLAN.md#unified-benchmark-definitions-kdl

## Goal

Define a single source of truth for benchmark definitions and generate both
`divan` and `gungraun` harnesses from it.

## Scope

- Add `benchmarks.kdl` in the core crate's `benches/` directory.
- Generate `divan_benchmarks.rs` and `gungraun_benchmarks.rs` from the KDL.
- Provide `cargo xtask gen-benchmarks` to regenerate the harnesses.

## KDL Schema

Each benchmark definition is represented as a `benchmark` node with a body.
Optional `preamble` and `type_def` nodes allow shared code insertion.

Example:

```kdl
preamble { code "use my_crate::Thing;" }

type_def name="Example" { code "struct Example;" }

benchmark name="load_defaults" module="config" return="Config" {
    body "black_box(Config::default())"
}
```

## Implementation Notes

- KDL path: `crates/{app}-core/benches/benchmarks.kdl`
- Generator command: `cargo xtask gen-benchmarks`
- Output files:
  - `crates/{app}-core/benches/divan_benchmarks.rs`
  - `crates/{app}-core/benches/gungraun_benchmarks.rs`
- Benchmarks are grouped into `mod <module>` in divan output.
- Gungraun output generates a single `library_benchmark_group!` with all benchmarks.

> **Note**: `{app}` refers to your project name. Template paths use Copier conditionals
> (e.g., `{{project_name + "-core" if has_core_library else "__skip_core__"}}`).

## Deep Links (Template Source)

These paths are in the template directory (conditional, only present when `has_benchmarks` is true):

- Generator: `template/xtask/src/commands/gen_benchmarks.rs`
- KDL source: `template/crates/{app}-core/benches/benchmarks.kdl`
- Divan output: `template/crates/{app}-core/benches/divan_benchmarks.rs`
- Gungraun output: `template/crates/{app}-core/benches/gungraun_benchmarks.rs`
- CI workflow: `template/.github/workflows/benchmarks.yml.jinja`

## Anti-Patterns

- Editing generated benchmark files directly.
- Adding benchmarks outside `benchmarks.kdl`.
- Using non-Rust identifiers for the `module` name.

## Test Cases

- `cargo xtask gen-benchmarks` regenerates harnesses without errors.
- `cargo bench --bench divan_benchmarks` runs.
- `cargo bench --bench gungraun_benchmarks` runs (Linux/Intel macOS only).
- `cargo test -p xtask` passes (generator unit test).

## Error Handling Matrix

| Scenario | Behavior | Message |
| --- | --- | --- |
| KDL file missing | Abort generation | "Failed to read …/benchmarks.kdl" |
| KDL parse error | Abort generation | "Failed to parse …/benchmarks.kdl" |
| Missing benchmark body | Abort generation | "benchmark <name> missing body" |
| No benchmarks defined | Abort generation | "No benchmark nodes found in benchmarks.kdl" |
| Write error | Abort generation | "Failed to write …" |
