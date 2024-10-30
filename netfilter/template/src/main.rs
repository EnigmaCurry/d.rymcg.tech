use askama::Template;
use clap::Parser;
use dotenvy::from_filename;
use env_logger;
use log::{error, info};
use std::collections::HashSet;
use std::env::{self, VarError};
mod parsers;
use parsers::Subnet;

#[derive(Parser)]
#[command(name = "RouterConfig")]
#[command(about = "Generates router configuration from environment or .env file")]
struct Cli {
    /// Path to the .env file
    #[arg(long)]
    env_file: Option<String>,

    /// Enable verbose output
    #[arg(short, long)]
    verbose: bool,

    /// Ignore all environment variables except for the default Bash and Rust environment variables
    #[arg(long)]
    ignore_env: bool,
}

#[derive(Template)]
#[template(path = "router.nft.txt")]
struct RouterTemplate {
    interface_lan: String,
    interface_wan: String,
    icmp_accept_lan: bool,
    icmp_accept_wan: bool,
    subnet_lan: Subnet,
}

impl RouterTemplate {
    fn from_env() -> Result<Self, Vec<String>> {
        let mut errors = Vec::new();

        let interface_lan = match get_string_var("INTERFACE_LAN") {
            Ok(val) => val,
            Err(err) => {
                errors.push(err);
                String::new() // Dummy value to proceed; won't be used if there are errors
            }
        };

        let interface_wan = match get_string_var("INTERFACE_WAN") {
            Ok(val) => val,
            Err(err) => {
                errors.push(err);
                String::new() // Dummy value to proceed; won't be used if there are errors
            }
        };

        let subnet_lan = match get_subnet_var("SUBNET_LAN") {
            Ok(val) => val,
            Err(err) => {
                errors.push(err);
                Subnet::new("0.0.0.0/0").unwrap() // Dummy value to proceed; won't be used if there are errors
            }
        };

        let icmp_accept_lan = get_bool_var("ICMP_ACCEPT_LAN").unwrap_or_else(|err| {
            errors.push(err);
            true // Default value
        });

        let icmp_accept_wan = get_bool_var("ICMP_ACCEPT_WAN").unwrap_or_else(|err| {
            errors.push(err);
            false // Default value
        });

        if !errors.is_empty() {
            return Err(errors);
        }

        Ok(RouterTemplate {
            interface_lan,
            interface_wan,
            subnet_lan,
            icmp_accept_lan,
            icmp_accept_wan,
        })
    }
}

/// Helper function to get a string environment variable with a custom error message.
fn get_string_var(var_name: &str) -> Result<String, String> {
    env::var(var_name).map_err(|_| format!("{} environment variable is not set.", var_name))
}

/// Helper function to get a subnet environment variable with detailed error messages.
fn get_subnet_var(var_name: &str) -> Result<Subnet, String> {
    let value = get_string_var(var_name)?;
    Subnet::new(&value).map_err(|_| format!("Invalid subnet format: {}={}", var_name, value))
}

/// Helper function to get a boolean environment variable with error handling.
fn get_bool_var(var_name: &str) -> Result<bool, String> {
    let value =
        env::var(var_name).map_err(|_| format!("{} environment variable is not set.", var_name))?;
    match value.as_str() {
        "true" => Ok(true),
        "false" => Ok(false),
        _ => Err(format!("Invalid boolean format: {}={}", var_name, value)),
    }
}

fn main() {
    // Parse command-line arguments
    let cli = Cli::parse();

    // Set RUST_LOG to info if verbose is enabled
    if cli.verbose {
        env::set_var("RUST_LOG", "info");
    }

    // Initialize the logger
    env_logger::init();

    // Load the specified .env file if provided
    if let Some(env_file) = cli.env_file {
        if from_filename(&env_file).is_ok() {
            info!("Loaded environment from file: {}", env_file);
        } else {
            error!("Failed to load environment from file: {}", env_file);
        }
    }

    // Ignore non-default environment variables if `--ignore-env` is set
    if cli.ignore_env {
        let default_vars: HashSet<&str> = [
            "HOME", "USER", "PWD", "OLDPWD", "SHELL", "PATH", "LANG", "TERM", "UID", "EUID",
            "LOGNAME", "HOSTNAME", "EDITOR", "VISUAL",
        ]
        .iter()
        .cloned()
        .collect();

        for (key, _) in env::vars() {
            if !default_vars.contains(key.as_str())
                && !key.starts_with("RUST")
                && !key.starts_with("CARGO")
            {
                env::remove_var(&key);
            }
        }
    }

    // Attempt to create the RouterTemplate from environment variables
    match RouterTemplate::from_env() {
        Ok(router) => println!("{}", router.render().unwrap()),
        Err(errors) => {
            for err in errors {
                eprintln!("Error: {}", err);
            }
            std::process::exit(1);
        }
    }
}
