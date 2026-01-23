//! Info command implementation

use clap::Args;
use serde::Serialize;
use tracing::{debug, instrument};

/// Arguments for the `info` subcommand.
#[derive(Args, Debug)]
pub struct InfoArgs {
    /// Output as JSON
    #[arg(long)]
    pub json: bool,
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
/// * `args` - Command-specific arguments
/// * `global_json` - Global `--json` flag from CLI (either works)
#[instrument(name = "cmd_info", skip_all, fields(json_output))]
pub fn cmd_info(args: InfoArgs, global_json: bool) -> anyhow::Result<()> {
    let info = PackageInfo::new();
    let json_output = args.json || global_json;

    debug!(
        args.json = args.json,
        global_json = global_json,
        json_output = json_output,
        "executing info command"
    );

    if json_output {
        println!("{}", serde_json::to_string_pretty(&info)?);
    } else {
        println!("{} {}", info.name, info.version);
        if !info.description.is_empty() {
            println!("{}", info.description);
        }
        if !info.license.is_empty() {
            println!("License: {}", info.license);
        }
        if !info.repository.is_empty() {
            println!("Repository: {}", info.repository);
        }
        if !info.homepage.is_empty() {
            println!("Homepage: {}", info.homepage);
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cmd_info_text_succeeds() {
        assert!(cmd_info(InfoArgs { json: false }, false).is_ok());
    }

    #[test]
    fn test_cmd_info_json_via_arg() {
        assert!(cmd_info(InfoArgs { json: true }, false).is_ok());
    }

    #[test]
    fn test_cmd_info_json_via_global() {
        assert!(cmd_info(InfoArgs { json: false }, true).is_ok());
    }
}
