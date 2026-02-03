---
status: accepted
date: 2026-01-04
decision-makers: Clay
consulted: Claude (Anthropic)
---

# Three-Layer Benchmarking Strategy with Unified Definitions

## Context and Problem Statement

This project includes both library components and CLI binaries. We need a benchmarking strategy that provides fast feedback during local development, stable regression detection in CI, and end-to-end validation of the compiled CLI. Wall-clock benchmarks alone are too noisy for reliable CI regression detection, but instruction-count benchmarks require Valgrind and don't reflect real-world timing. How do we get the benefits of both approaches without duplicating benchmark definitions?

## Decision Drivers

* Need fast iteration cycles during local development
* CI benchmarks must be deterministic and comparable across runs/machines
* CLI startup time and I/O overhead matter to users but aren't captured by library benchmarks
* Benchmark definitions shouldn't drift between harnesses
* Current dev machine is Intel Mac (x86_64), so Valgrind is available locally
* Future-proofing: ARM Macs don't support Valgrind, so CI must be the primary gungraun environment

## Considered Options

* Divan only
* Criterion only
* Divan + Hyperfine
* Divan + Gungraun + Hyperfine (three-layer approach)
* Divan + Gungraun + Hyperfine with unified KDL definitions (facet-style)

## Decision Outcome

Chosen option: "Divan + Gungraun + Hyperfine with unified KDL definitions", because it provides the best coverage across development workflows (fast local iteration, stable CI regression detection, end-to-end CLI validation) while keeping benchmark definitions in sync through code generation from a single source of truth.

### Consequences

* Good, because divan provides fast wall-clock feedback with an ergonomic API during active development
* Good, because gungraun provides deterministic instruction counts that don't flap in CI
* Good, because hyperfine catches CLI-level regressions (startup time, arg parsing, I/O) that library benchmarks miss
* Good, because unified KDL definitions prevent drift between harnesses
* Bad, because the KDL generator adds initial implementation complexity
* Bad, because gungraun requires Valgrind, limiting local execution to Intel Macs and Linux
* Neutral, because generated benchmark files require a regeneration step after editing definitions

### Confirmation

The implementation is confirmed when:

1. `cargo xtask gen-benchmarks` successfully generates both `divan_benchmarks.rs` and `gungraun_benchmarks.rs` from `benchmarks.kdl`
2. `cargo bench --bench divan_benchmarks` runs locally and produces timing output
3. `cargo bench --bench gungraun_benchmarks` runs (on Intel Mac or Linux) and produces instruction counts
4. `./scripts/bench-cli.sh` runs hyperfine against the release binary
5. GitHub Actions CI runs all three benchmark types on Linux runners

## Pros and Cons of the Options

### Divan only

Simple, ergonomic library benchmarking with wall-clock timing.

* Good, because minimal setup and excellent API ergonomics
* Good, because fast compile times compared to Criterion
* Good, because built-in allocation profiling
* Bad, because wall-clock results are noisy and non-deterministic
* Bad, because CI results vary between runs, making regression detection unreliable
* Bad, because no coverage of CLI-level performance

### Criterion only

The established standard for Rust benchmarking, also wall-clock based.

* Good, because mature ecosystem with HTML reports and comparison tooling
* Good, because widely understood in the Rust community
* Bad, because slower compile times than divan
* Bad, because more verbose API than divan
* Bad, because still wall-clock based, so same CI noise problems
* Bad, because no coverage of CLI-level performance

### Divan + Hyperfine

Library benchmarks with divan, CLI benchmarks with hyperfine.

* Good, because covers both library and CLI performance
* Good, because hyperfine provides excellent CLI comparison features
* Bad, because both are wall-clock based, so CI regression detection remains noisy
* Neutral, because simpler than three-layer approach but less comprehensive

### Divan + Gungraun + Hyperfine (three-layer approach)

Full coverage: divan for local iteration, gungraun for CI stability, hyperfine for CLI.

* Good, because each layer addresses a specific need
* Good, because gungraun provides deterministic CI results
* Good, because hyperfine catches end-to-end regressions
* Bad, because benchmark definitions must be maintained in two places (divan and gungraun files)
* Bad, because definitions can drift, causing inconsistent coverage

### Divan + Gungraun + Hyperfine with unified KDL definitions

Three-layer approach with code generation from a single KDL definition file.

* Good, because single source of truth prevents definition drift
* Good, because adding a benchmark automatically creates both divan and gungraun versions
* Good, because KDL is human-readable and easy to edit
* Good, because follows proven pattern from facet-rs project
* Bad, because requires implementing and maintaining a code generator
* Bad, because adds a regeneration step to the workflow
* Neutral, because generated files can be committed or gitignored (trade-off between reproducibility and diff noise)

## Tiered Adoption

The three-layer benchmarking strategy has **tiered optionality**:

| Flag | Default | Purpose |
|------|---------|---------|
| `has_benchmarks` | preset-dependent | Master switch for all benchmarking |
| (divan) | bundled with `has_benchmarks` | Fast wall-clock benchmarks (always available) |
| `has_gungraun` | `false` | Instruction-count benchmarks (Valgrind required) |
| (hyperfine) | bundled with `has_benchmarks` | CLI benchmarks via shell script |

**Platform Note:** Gungraun requires Valgrind, which is not available on ARM Macs (Apple Silicon). Users on Apple Silicon should either:

1. Leave `has_gungraun=false` (default) and run gungraun only in CI
2. Use a Linux VM or container for local gungraun execution

When `has_gungraun=false`:
- Gungraun dependency is not added to Cargo.toml
- `gungraun_benchmarks.rs` is not generated
- `just bench-gungraun` recipe is not available
- CI benchmark workflow still runs (divan + hyperfine only)

## More Information

The facet-rs project's benchmark system served as the primary inspiration for the unified definition approach:

* https://facet.rs/contribute/benchmarks/
* https://github.com/facet-rs/facet/tree/main/facet-json/benches
