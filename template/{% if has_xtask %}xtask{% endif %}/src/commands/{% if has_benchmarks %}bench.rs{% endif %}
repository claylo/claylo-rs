//! Benchmark runner command for xtask.

use clap::Args;
use std::process::Command;

use crate::workspace_root;

#[derive(Args, Debug)]
pub struct BenchArgs {
    /// Skip divan (wall-clock) benchmarks
    #[arg(long)]
    pub skip_divan: bool,

    /// Skip gungraun (instruction count) benchmarks
    #[arg(long)]
    pub skip_gungraun: bool,

    /// Skip CLI (hyperfine) benchmarks
    #[arg(long)]
    pub skip_cli: bool,

    /// Run in quick mode (fewer iterations)
    #[arg(long)]
    pub quick: bool,

    /// Filter benchmarks by name pattern
    #[arg(long)]
    pub filter: Option<String>,
}

pub fn cmd_bench(args: BenchArgs) -> Result<(), String> {
    let root = workspace_root();
    let reports_dir = root.join("bench-reports");

    std::fs::create_dir_all(&reports_dir)
        .map_err(|e| format!("Failed to create bench-reports directory: {e}"))?;

    let mut any_run = false;

    // Divan benchmarks
    if !args.skip_divan {
        println!("\n=== Running Divan Benchmarks (wall-clock) ===\n");

        let mut cmd = Command::new("cargo");
        cmd.current_dir(&root)
            .args(["bench", "--bench", "divan_benchmarks"]);

        if let Some(ref filter) = args.filter {
            cmd.args(["--", filter]);
        }

        let status = cmd
            .status()
            .map_err(|e| format!("Failed to run divan: {e}"))?;

        if !status.success() {
            return Err("Divan benchmarks failed".to_string());
        }
        any_run = true;
    }

    // Gungraun benchmarks
    if !args.skip_gungraun {
        println!("\n=== Running Gungraun Benchmarks (instruction count) ===\n");

        // Check if valgrind is available
        let valgrind_check = Command::new("which")
            .arg("valgrind")
            .output()
            .map_err(|e| format!("Failed to check for valgrind: {e}"))?;

        if !valgrind_check.status.success() {
            println!("Warning: Valgrind not found. Skipping gungraun benchmarks.");
            println!(
                "Install with: brew install valgrind (macOS Intel) or apt install valgrind (Linux)"
            );
            println!("Note: Valgrind does not support macOS ARM (M1/M2/M3).\n");
        } else {
            let mut cmd = Command::new("cargo");
            cmd.current_dir(&root)
                .args(["bench", "--bench", "gungraun_benchmarks"]);

            if let Some(ref filter) = args.filter {
                cmd.args(["--", filter]);
            }

            let status = cmd
                .status()
                .map_err(|e| format!("Failed to run gungraun: {e}"))?;

            if !status.success() {
                return Err("Gungraun benchmarks failed".to_string());
            }
            any_run = true;
        }
    }

    // CLI benchmarks with hyperfine
    if !args.skip_cli {
        println!("\n=== Running CLI Benchmarks (hyperfine) ===\n");

        // Check if hyperfine is available
        let hyperfine_check = Command::new("which")
            .arg("hyperfine")
            .output()
            .map_err(|e| format!("Failed to check for hyperfine: {e}"))?;

        if !hyperfine_check.status.success() {
            println!("Warning: hyperfine not found. Skipping CLI benchmarks.");
            println!("Install with: brew install hyperfine (or cargo install hyperfine)\n");
        } else {
            let script = root.join("scripts").join("bench-cli.sh");

            if !script.exists() {
                println!("Warning: scripts/bench-cli.sh not found. Skipping CLI benchmarks.\n");
            } else {
                let mut cmd = Command::new("bash");
                cmd.current_dir(&root).arg(&script);

                if args.quick {
                    cmd.arg("--quick");
                }

                let status = cmd
                    .status()
                    .map_err(|e| format!("Failed to run CLI benchmarks: {e}"))?;

                if !status.success() {
                    return Err("CLI benchmarks failed".to_string());
                }
                any_run = true;
            }
        }
    }

    if any_run {
        println!("\n=== Benchmark Complete ===");
        println!("Results saved to bench-reports/");
    } else {
        println!("No benchmarks were run. Check that required tools are installed.");
    }

    Ok(())
}
