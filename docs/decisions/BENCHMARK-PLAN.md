# Benchmark Implementation Plan

This document describes a three-layer benchmarking strategy for a Rust project that includes both library components and CLI binaries. The approach is inspired by the facet-rs project's dual-harness system.

## Overview

We're implementing three complementary benchmarking layers:

| Layer | Tool | Measures | Purpose |
|-------|------|----------|---------|
| 1 | **divan** | Wall-clock time | Fast local iteration on library code |
| 2 | **gungraun** | CPU instructions (via Valgrind) | Deterministic CI regression detection |
| 3 | **hyperfine** | Wall-clock time | End-to-end CLI binary benchmarks |

Layers 1 and 2 share benchmark definitions via a KDL configuration file, generating separate Rust benchmark files for each harness. This prevents drift and reduces maintenance burden.

---

## Prerequisites

- Rust 1.80.0+ (divan requirement)
- Valgrind installed (for gungraun): `brew install valgrind` on macOS Intel, `apt install valgrind` on Linux
- hyperfine installed: `brew install hyperfine` or `cargo install hyperfine`
- KDL parser: we'll use the `kdl` crate for parsing benchmark definitions

---

## Directory Structure

```
project-root/
├── Cargo.toml
├── benches/
│   ├── benchmarks.kdl           # Single source of truth for benchmark definitions
│   ├── divan_benchmarks.rs      # Generated from benchmarks.kdl
│   └── gungraun_benchmarks.rs   # Generated from benchmarks.kdl
├── scripts/
│   ├── bench-cli.sh             # hyperfine CLI benchmarks
│   └── generate-benchmarks.rs   # KDL → Rust codegen script
├── bench-reports/               # Output directory for results
│   ├── divan-latest.txt
│   ├── gungraun-latest.txt
│   └── hyperfine-latest.json
└── xtask/                       # Optional: cargo xtask for automation
    ├── Cargo.toml
    └── src/
        └── main.rs
```

---

## Layer 1: Divan (Wall-Clock Benchmarks)

### Installation

Add to `Cargo.toml`:

```toml
[dev-dependencies]
divan = "0.1"

[[bench]]
name = "divan_benchmarks"
harness = false
```

### Example Benchmark Structure

```rust
// benches/divan_benchmarks.rs

fn main() {
    divan::main();
}

mod parsing {
    use super::*;
    
    #[divan::bench]
    fn parse_simple() -> MyType {
        my_crate::parse(divan::black_box(SIMPLE_INPUT))
    }
    
    #[divan::bench(args = [100, 1000, 10000])]
    fn parse_array(n: usize) -> Vec<Item> {
        my_crate::parse(divan::black_box(&generate_array_input(n)))
    }
}

mod transformation {
    use super::*;
    
    #[divan::bench]
    fn transform_data(bencher: divan::Bencher) {
        let input = setup_complex_input();
        bencher.bench_local(|| {
            my_crate::transform(divan::black_box(&input))
        });
    }
}
```

### Running

```bash
# Run all divan benchmarks
cargo bench --bench divan_benchmarks

# Run specific benchmark by name
cargo bench --bench divan_benchmarks -- parse_simple

# Run benchmarks matching a pattern
cargo bench --bench divan_benchmarks -- parsing
```

### Key Divan Features to Use

- `#[divan::bench]` - Basic benchmark
- `#[divan::bench(args = [...])]` - Parameterized benchmarks
- `#[divan::bench_group]` - Group related benchmarks with shared config
- `divan::black_box()` - Prevent compiler optimization
- `bencher.counter(BytesCount::new(n))` - Throughput measurement
- `divan::AllocProfiler` - Track allocations (add as global allocator)

---

## Layer 2: Gungraun (Instruction Count Benchmarks)

### Installation

Add to `Cargo.toml`:

```toml
[dev-dependencies]
gungraun = "0.17"

[[bench]]
name = "gungraun_benchmarks"
harness = false
```

### Example Benchmark Structure

```rust
// benches/gungraun_benchmarks.rs

use gungraun::{library_benchmark, library_benchmark_group, main};
use std::hint::black_box;

#[library_benchmark]
#[bench::simple(SIMPLE_INPUT)]
fn parse_simple(input: &str) -> MyType {
    black_box(my_crate::parse(input))
}

#[library_benchmark]
#[bench::small(generate_array_input(100))]
#[bench::medium(generate_array_input(1000))]
#[bench::large(generate_array_input(10000))]
fn parse_array(input: String) -> Vec<Item> {
    black_box(my_crate::parse(&input))
}

library_benchmark_group!(
    name = parsing_group;
    benchmarks = parse_simple, parse_array
);

fn main() {
    main!(library_benchmark_groups = parsing_group);
}
```

### Running

```bash
# Run all gungraun benchmarks
cargo bench --bench gungraun_benchmarks

# Run specific benchmark
cargo bench --bench gungraun_benchmarks -- parse_simple
```

### Key Gungraun Features

- Measures: Instructions, L1/L2 cache hits, RAM accesses, estimated cycles
- Deterministic across runs and machines
- Single-shot execution (no statistical sampling needed)
- Valgrind client requests for fine-grained measurement control

### Platform Notes

- **macOS Intel (x86_64)**: Fully supported
- **macOS ARM (M1/M2/M3)**: NOT supported (Valgrind limitation)
- **Linux x86_64/ARM**: Fully supported
- **Windows**: NOT supported

---

## Layer 3: Hyperfine (CLI Benchmarks)

### Script: `scripts/bench-cli.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Build release binary first
cargo build --release

BINARY="./target/release/my-cli"
RESULTS_DIR="./bench-reports"
mkdir -p "$RESULTS_DIR"

echo "=== CLI Benchmark Suite ==="

# Basic invocation benchmark
hyperfine \
    --warmup 3 \
    --min-runs 10 \
    --export-json "$RESULTS_DIR/hyperfine-latest.json" \
    --export-markdown "$RESULTS_DIR/hyperfine-latest.md" \
    "$BINARY --version"

# Compare different commands/flags
hyperfine \
    --warmup 3 \
    --export-json "$RESULTS_DIR/hyperfine-commands.json" \
    "$BINARY process input.txt" \
    "$BINARY process --fast input.txt" \
    "$BINARY process --parallel input.txt"

# Parameterized benchmark (e.g., varying input sizes)
hyperfine \
    --warmup 2 \
    --parameter-scan size 100 1000 -D 100 \
    --export-json "$RESULTS_DIR/hyperfine-scaling.json" \
    "$BINARY generate --count {size} | $BINARY process"

# Cold cache benchmark (Linux only)
# hyperfine \
#     --prepare 'sync; echo 3 | sudo tee /proc/sys/vm/drop_caches' \
#     "$BINARY process large-file.txt"

echo "Results saved to $RESULTS_DIR/"
```

### Running

```bash
chmod +x scripts/bench-cli.sh
./scripts/bench-cli.sh
```

---

## Unified Benchmark Definitions (KDL)

### File: `benches/benchmarks.kdl`

This is the single source of truth. A generator script reads this and produces both `divan_benchmarks.rs` and `gungraun_benchmarks.rs`.

```kdl
// benches/benchmarks.kdl

// Type definitions used by benchmarks
type_def name="SimpleRecord" {
    code r#"
#[derive(Debug, Clone, PartialEq)]
pub struct SimpleRecord {
    pub id: u64,
    pub name: String,
    pub active: bool,
}
"#
}

type_def name="NestedData" {
    code r#"
#[derive(Debug, Clone, PartialEq)]
pub struct NestedData {
    pub items: Vec<SimpleRecord>,
    pub metadata: std::collections::HashMap<String, String>,
}
"#
}

// Benchmark definitions
benchmark name="parse_simple" type="SimpleRecord" category="micro" {
    input r#"{"id": 42, "name": "test", "active": true}"#
}

benchmark name="parse_array_small" type="Vec<SimpleRecord>" category="synthetic" {
    generated "records" count=100
}

benchmark name="parse_array_medium" type="Vec<SimpleRecord>" category="synthetic" {
    generated "records" count=1000
}

benchmark name="parse_array_large" type="Vec<SimpleRecord>" category="synthetic" {
    generated "records" count=10000
}

benchmark name="parse_nested" type="NestedData" category="synthetic" {
    generated "nested_records" depth=3
}

// Realistic benchmarks using corpus files
benchmark name="large_real_world" type="RealWorldType" category="realistic" {
    file "corpus/real-data.json"
}
```

### Categories

- **micro**: Tiny inputs, testing minimal overhead
- **synthetic**: Generated data, testing specific patterns
- **realistic**: Real-world data files

---

## Benchmark Generator

### File: `scripts/generate-benchmarks.rs`

This can be run via `cargo xtask gen-benchmarks` or as a standalone script.

```rust
//! Generates divan and gungraun benchmark files from benchmarks.kdl
//!
//! Usage: cargo run --manifest-path scripts/Cargo.toml

use std::fs;
use std::path::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let kdl_path = Path::new("benches/benchmarks.kdl");
    let kdl_content = fs::read_to_string(kdl_path)?;
    let doc: kdl::KdlDocument = kdl_content.parse()?;
    
    let divan_code = generate_divan(&doc)?;
    let gungraun_code = generate_gungraun(&doc)?;
    
    fs::write("benches/divan_benchmarks.rs", divan_code)?;
    fs::write("benches/gungraun_benchmarks.rs", gungraun_code)?;
    
    println!("Generated benchmark files from benchmarks.kdl");
    Ok(())
}

fn generate_divan(doc: &kdl::KdlDocument) -> Result<String, Box<dyn std::error::Error>> {
    let mut code = String::from(r#"
// AUTO-GENERATED FROM benches/benchmarks.kdl
// Do not edit directly. Run `cargo xtask gen-benchmarks` to regenerate.

use std::hint::black_box;

fn main() {
    divan::main();
}

"#);
    
    // Extract type definitions
    for node in doc.nodes() {
        if node.name().value() == "type_def" {
            if let Some(type_code) = node.children()
                .and_then(|c| c.get("code"))
                .and_then(|n| n.entries().first())
                .and_then(|e| e.value().as_string()) 
            {
                code.push_str(type_code);
                code.push_str("\n\n");
            }
        }
    }
    
    // Group benchmarks by category
    code.push_str("mod micro {\n    use super::*;\n\n");
    for node in doc.nodes().filter(|n| n.name().value() == "benchmark") {
        let category = node.get("category")
            .and_then(|e| e.value().as_string())
            .unwrap_or("micro");
        if category == "micro" {
            code.push_str(&generate_divan_benchmark(node)?);
        }
    }
    code.push_str("}\n\n");
    
    code.push_str("mod synthetic {\n    use super::*;\n\n");
    for node in doc.nodes().filter(|n| n.name().value() == "benchmark") {
        let category = node.get("category")
            .and_then(|e| e.value().as_string())
            .unwrap_or("micro");
        if category == "synthetic" {
            code.push_str(&generate_divan_benchmark(node)?);
        }
    }
    code.push_str("}\n\n");
    
    code.push_str("mod realistic {\n    use super::*;\n\n");
    for node in doc.nodes().filter(|n| n.name().value() == "benchmark") {
        let category = node.get("category")
            .and_then(|e| e.value().as_string())
            .unwrap_or("micro");
        if category == "realistic" {
            code.push_str(&generate_divan_benchmark(node)?);
        }
    }
    code.push_str("}\n");
    
    Ok(code)
}

fn generate_divan_benchmark(node: &kdl::KdlNode) -> Result<String, Box<dyn std::error::Error>> {
    let name = node.get("name")
        .and_then(|e| e.value().as_string())
        .ok_or("benchmark missing name")?;
    let type_name = node.get("type")
        .and_then(|e| e.value().as_string())
        .ok_or("benchmark missing type")?;
    
    // Determine input source
    let input_expr = if let Some(children) = node.children() {
        if let Some(input_node) = children.get("input") {
            let input_str = input_node.entries().first()
                .and_then(|e| e.value().as_string())
                .ok_or("input node missing value")?;
            format!("r#\"{}\"#", input_str)
        } else if let Some(gen_node) = children.get("generated") {
            // Handle generated inputs
            "generate_test_input()".to_string()
        } else if let Some(file_node) = children.get("file") {
            let path = file_node.entries().first()
                .and_then(|e| e.value().as_string())
                .ok_or("file node missing path")?;
            format!("include_str!(\"{}\")", path)
        } else {
            return Err("benchmark has no input source".into());
        }
    } else {
        return Err("benchmark has no children".into());
    };
    
    Ok(format!(r#"
    #[divan::bench]
    fn {name}() -> {type_name} {{
        let input = {input_expr};
        black_box(my_crate::parse(black_box(input)))
    }}
"#))
}

fn generate_gungraun(doc: &kdl::KdlDocument) -> Result<String, Box<dyn std::error::Error>> {
    let mut code = String::from(r#"
// AUTO-GENERATED FROM benches/benchmarks.kdl
// Do not edit directly. Run `cargo xtask gen-benchmarks` to regenerate.

use gungraun::{library_benchmark, library_benchmark_group, main};
use std::hint::black_box;

"#);
    
    // Extract type definitions (same as divan)
    for node in doc.nodes() {
        if node.name().value() == "type_def" {
            if let Some(type_code) = node.children()
                .and_then(|c| c.get("code"))
                .and_then(|n| n.entries().first())
                .and_then(|e| e.value().as_string()) 
            {
                code.push_str(type_code);
                code.push_str("\n\n");
            }
        }
    }
    
    // Generate benchmark functions
    let mut benchmark_names = Vec::new();
    for node in doc.nodes().filter(|n| n.name().value() == "benchmark") {
        let name = node.get("name")
            .and_then(|e| e.value().as_string())
            .unwrap_or("unnamed");
        benchmark_names.push(name.to_string());
        code.push_str(&generate_gungraun_benchmark(node)?);
    }
    
    // Generate benchmark group
    let names_list = benchmark_names.join(", ");
    code.push_str(&format!(r#"
library_benchmark_group!(
    name = all_benchmarks;
    benchmarks = {names_list}
);

fn main() {{
    main!(library_benchmark_groups = all_benchmarks);
}}
"#));
    
    Ok(code)
}

fn generate_gungraun_benchmark(node: &kdl::KdlNode) -> Result<String, Box<dyn std::error::Error>> {
    let name = node.get("name")
        .and_then(|e| e.value().as_string())
        .ok_or("benchmark missing name")?;
    let type_name = node.get("type")
        .and_then(|e| e.value().as_string())
        .ok_or("benchmark missing type")?;
    
    // For gungraun, we pass input as a parameter
    let input_expr = if let Some(children) = node.children() {
        if let Some(input_node) = children.get("input") {
            let input_str = input_node.entries().first()
                .and_then(|e| e.value().as_string())
                .ok_or("input node missing value")?;
            format!("r#\"{}\"#.to_string()", input_str)
        } else {
            "generate_test_input()".to_string()
        }
    } else {
        return Err("benchmark has no children".into());
    };
    
    Ok(format!(r#"
#[library_benchmark]
#[bench::default({input_expr})]
fn {name}(input: String) -> {type_name} {{
    black_box(my_crate::parse(black_box(&input)))
}}
"#))
}
```

---

## Cargo xtask Integration

### File: `xtask/Cargo.toml`

```toml
[package]
name = "xtask"
version = "0.1.0"
edition = "2021"

[dependencies]
kdl = "4"
clap = { version = "4", features = ["derive"] }
```

### File: `xtask/src/main.rs`

```rust
use clap::{Parser, Subcommand};
use std::process::Command;

#[derive(Parser)]
#[command(name = "xtask")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate benchmark files from benchmarks.kdl
    GenBenchmarks,
    
    /// Run all benchmarks and generate reports
    Bench {
        /// Skip gungraun (instruction count) benchmarks
        #[arg(long)]
        skip_gungraun: bool,
        
        /// Skip divan (wall-clock) benchmarks
        #[arg(long)]
        skip_divan: bool,
        
        /// Skip hyperfine (CLI) benchmarks
        #[arg(long)]
        skip_cli: bool,
    },
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    
    match cli.command {
        Commands::GenBenchmarks => {
            // Run the generator script
            println!("Generating benchmarks from benches/benchmarks.kdl...");
            // Include generator logic here or shell out to a script
            generate_benchmarks()?;
        }
        Commands::Bench { skip_gungraun, skip_divan, skip_cli } => {
            std::fs::create_dir_all("bench-reports")?;
            
            if !skip_divan {
                println!("\n=== Running Divan Benchmarks ===\n");
                let output = Command::new("cargo")
                    .args(["bench", "--bench", "divan_benchmarks"])
                    .output()?;
                std::fs::write("bench-reports/divan-latest.txt", &output.stdout)?;
                println!("{}", String::from_utf8_lossy(&output.stdout));
            }
            
            if !skip_gungraun {
                println!("\n=== Running Gungraun Benchmarks ===\n");
                let output = Command::new("cargo")
                    .args(["bench", "--bench", "gungraun_benchmarks"])
                    .output()?;
                std::fs::write("bench-reports/gungraun-latest.txt", &output.stdout)?;
                println!("{}", String::from_utf8_lossy(&output.stdout));
            }
            
            if !skip_cli {
                println!("\n=== Running CLI Benchmarks ===\n");
                Command::new("./scripts/bench-cli.sh")
                    .status()?;
            }
            
            println!("\n=== Benchmark Results ===");
            println!("Reports saved to bench-reports/");
        }
    }
    
    Ok(())
}

fn generate_benchmarks() -> Result<(), Box<dyn std::error::Error>> {
    // Inline the generator logic or call external script
    println!("  → Generated benches/divan_benchmarks.rs");
    println!("  → Generated benches/gungraun_benchmarks.rs");
    Ok(())
}
```

### Add to workspace `Cargo.toml`

```toml
[workspace]
members = [".", "xtask"]
```

### Add alias in `.cargo/config.toml`

```toml
[alias]
xtask = "run --manifest-path xtask/Cargo.toml --"
```

---

## CI Integration

### GitHub Actions: `.github/workflows/benchmarks.yml`

```yaml
name: Benchmarks

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  benchmarks:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Rust
        uses: dtolnay/rust-action@stable
      
      - name: Install Valgrind
        run: sudo apt-get update && sudo apt-get install -y valgrind
      
      - name: Install hyperfine
        run: |
          wget https://github.com/sharkdp/hyperfine/releases/download/v1.18.0/hyperfine_1.18.0_amd64.deb
          sudo dpkg -i hyperfine_1.18.0_amd64.deb
      
      - name: Generate benchmarks
        run: cargo xtask gen-benchmarks
      
      - name: Run Divan benchmarks
        run: cargo bench --bench divan_benchmarks | tee bench-reports/divan-ci.txt
      
      - name: Run Gungraun benchmarks
        run: cargo bench --bench gungraun_benchmarks | tee bench-reports/gungraun-ci.txt
      
      - name: Run CLI benchmarks
        run: ./scripts/bench-cli.sh
      
      - name: Upload benchmark results
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-results
          path: bench-reports/
      
      # Optional: Use Bencher for tracking over time
      # - uses: bencherdev/bencher@main
      #   with:
      #     command: cargo bench --bench gungraun_benchmarks
      #     adapter: rust_gungraun
```

---

## Quick Reference Commands

```bash
# Generate benchmark code from KDL definitions
cargo xtask gen-benchmarks

# Run all benchmarks
cargo xtask bench

# Run only divan (fast, local iteration)
cargo bench --bench divan_benchmarks

# Run only gungraun (deterministic, CI-stable)
cargo bench --bench gungraun_benchmarks

# Run specific benchmark by name
cargo bench --bench divan_benchmarks -- parse_simple

# Run CLI benchmarks
./scripts/bench-cli.sh

# Skip certain benchmark types
cargo xtask bench --skip-gungraun
cargo xtask bench --skip-cli
```

---

## Implementation Checklist

- [ ] Add `divan` and `gungraun` to `[dev-dependencies]`
- [ ] Create `benches/benchmarks.kdl` with initial benchmark definitions
- [ ] Create `benches/divan_benchmarks.rs` (can start manually, then generate)
- [ ] Create `benches/gungraun_benchmarks.rs` (can start manually, then generate)
- [ ] Set up `xtask/` crate for automation
- [ ] Create `scripts/bench-cli.sh` for hyperfine CLI benchmarks
- [ ] Add `.cargo/config.toml` with xtask alias
- [ ] Create `bench-reports/` directory (add to `.gitignore` except for `.gitkeep`)
- [ ] Add GitHub Actions workflow for CI benchmarks
- [ ] Add benchmark corpus files if using realistic benchmarks

---

## Notes

1. **Start simple**: You don't need the full KDL → codegen system on day one. Start with hand-written divan benchmarks, then add gungraun, then automate with the generator once you have enough benchmarks that maintenance becomes tedious.

2. **Gungraun platform limitation**: Gungraun requires Valgrind, which doesn't support macOS ARM (M1/M2/M3). If your dev machine is Apple Silicon, run gungraun only in CI on Linux runners.

3. **Hyperfine for user-facing perf**: Library benchmarks miss startup time, argument parsing, and I/O. Use hyperfine to catch regressions in the complete user experience.

4. **Generated files**: Add a header comment to generated files warning not to edit them directly. Consider adding them to `.gitignore` or committing them (trade-off: reproducibility vs. noise in diffs).

5. **Benchmark hygiene**: Close other applications when running wall-clock benchmarks locally. Gungraun is immune to this but divan is not.
