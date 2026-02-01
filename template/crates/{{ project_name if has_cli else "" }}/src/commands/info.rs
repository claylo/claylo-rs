//! Info command implementation

use clap::Args;
use owo_colors::OwoColorize;
use serde::Serialize;
use tracing::{debug, instrument};

/// Arguments for the `info` subcommand.
#[derive(Args, Debug, Default)]
pub struct InfoArgs {
    // No subcommand-specific arguments; uses global --json flag
}

#[derive(Serialize)]
struct PackageInfo {
    name: &'static str,
    version: &'static str,
    #[serde(skip_serializing_if = "str::is_empty")]
    description: &'static str,
    #[serde(skip_serializing_if = "str::is_empty")]
    repository: &'static str,
    #[serde(skip_serializing_if = "str::is_empty")]
    homepage: &'static str,
    #[serde(skip_serializing_if = "str::is_empty")]
    license: &'static str,
}

impl PackageInfo {
    const fn new() -> Self {
        Self {
            name: env!("CARGO_PKG_NAME"),
            version: env!("CARGO_PKG_VERSION"),
            description: env!("CARGO_PKG_DESCRIPTION"),
            repository: env!("CARGO_PKG_REPOSITORY"),
            homepage: env!("CARGO_PKG_HOMEPAGE"),
            license: env!("CARGO_PKG_LICENSE"),
        }
    }
}

/// Print package information
///
/// # Arguments
/// * `global_json` - Global `--json` flag from CLI
#[instrument(name = "cmd_info", skip_all, fields(json_output))]
pub fn cmd_info(_args: InfoArgs, global_json: bool) -> anyhow::Result<()> {
    let info = PackageInfo::new();

    debug!(
        json_output = global_json,
        "executing info command"
    );

    if global_json {
        println!("{}", serde_json::to_string_pretty(&info)?);
    } else {
        println!("{} {}", info.name.bold(), info.version.green());
        if !info.description.is_empty() {
            println!("{}", info.description);
        }
        if !info.license.is_empty() {
            println!("{}: {}", "License".dimmed(), info.license);
        }
        if !info.repository.is_empty() {
            println!("{}: {}", "Repository".dimmed(), info.repository.cyan());
        }
        if !info.homepage.is_empty() {
            println!("{}: {}", "Homepage".dimmed(), info.homepage.cyan());
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cmd_info_text_succeeds() {
        assert!(cmd_info(InfoArgs::default(), false).is_ok());
    }

    #[test]
    fn test_cmd_info_json_via_global() {
        assert!(cmd_info(InfoArgs::default(), true).is_ok());
    }
}
