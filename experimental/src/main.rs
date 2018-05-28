#![recursion_limit = "1024"]

extern crate reqwest;
extern crate chrono;
extern crate openssl_probe;
extern crate uuid;
extern crate serde;
extern crate serde_json;
extern crate serde_yaml;
extern crate urlencoding;
extern crate valico;

#[macro_use] extern crate log;
extern crate env_logger;

#[macro_use] extern crate clap;
#[macro_use] extern crate serde_derive;
#[macro_use] extern crate error_chain;
#[macro_use] extern crate human_panic;

mod errors;
mod process;
mod config;

use std::ops::Deref;
use std::fs::File;
use std::io::Read;

use std::env;
use std::io::Write;

use errors::ResultExt;
use config::Configuration;

fn main() {
    setup_panic!();

    if let Err(e) = run() {
        error!("{}", e.format());
        ::std::process::exit(1);
    }
}

fn run() -> errors::Result<()> {

    let usage = format!("{} [flags] [options] [subcommand] --help", crate_name!());
    let mut app = clap::App::new(crate_name!())
        .setting(clap::AppSettings::ArgRequiredElseHelp)
        .version(crate_version!())
        .author("Copyright: http://cade.works, github: https://github.com/cadeworks/cade")
        .about("Containerized Application DEployment (CADE) automation toolkit")
        .usage(usage.deref())
        .arg(clap::Arg::with_name("log-level")
            .long("log-level")
            .possible_values(&["warn", "info", "debug", "trace"])
            .default_value("info")
            .help("Set logging level. \
             RUST_LOG environment variable overrides this setting, eg. set RUST_LOG to 'error,clap=debug'"))
        .arg(clap::Arg::with_name("quiet")
            .short("q")
            .help("Silence all logging output"))
        .arg(clap::Arg::with_name("log-color")
            .long("log-color")
            .takes_value(true)
            .possible_values(&["auto", "always", "never"])
            .default_value("auto")
            .help("Configure if log traces should be colorized. RUST_LOG_STYLE environment variable overrides this setting."))
        .subcommand(clap::SubCommand::with_name("apply")
            .about("Applies deployment configuration file")
            .arg(clap::Arg::with_name("config")
                .help("Configuration file location")
                .value_name("config-path")
                .required(false)
                .default_value("./cade.yaml")
            )
        );
    let matches = app.clone().get_matches();

    init_logging(
        matches.is_present("quiet"),
        matches.value_of("log-level").unwrap(),
        matches.value_of("log-color").unwrap());

    openssl_probe::init_ssl_cert_env_vars();

    if let Some(matches) = matches.subcommand_matches("apply") {
        let config_path = String::from(matches.value_of("config").unwrap());
        let result = run_apply(config_path);
        return result
    }

    return app.print_help().chain_err(|| "failure to print help message")
}

fn run_apply(config_path: String) -> errors::Result<()> {

    let error_message = format!("failure to open configuration file {}", config_path);
    let mut file = File::open(config_path.clone()).chain_err(move || error_message)?;

    let mut contents = String::new();
    let error_message = format!("failure to read configuration file {}", config_path);
    file.read_to_string(&mut contents).chain_err(move || error_message)?;

    let error_message = format!("configuration file '{}' is invalid", config_path);
    let config: Configuration = serde_yaml::from_str(&contents).chain_err(move || error_message)?;

    info!("deep config validation");
    let error_message = format!("configuration file '{}' is invalid", config_path);
    config::validate_config(&config).chain_err(move || error_message)?;

    return Ok(());
}

pub fn init_logging(quite: bool, level: &str, color_style: &str) -> () {
    if quite {
        return;
    }

    let mut builder = env_logger::Builder::new();
    let write_style = env::var("RUST_LOG_STYLE").unwrap_or(String::from(color_style));
    builder.parse_write_style(&write_style);
    builder.format(|formatter, record| {
        let mut style = formatter.style();
        let color = match record.level() {
            log::Level::Error => {
                env_logger::fmt::Color::Red
            }
            log::Level::Warn => {
                env_logger::fmt::Color::Yellow
            }
            log::Level::Info => {
                env_logger::fmt::Color::Green
            }
            log::Level::Debug => {
                env_logger::fmt::Color::Cyan
            }
            log::Level::Trace => {
                env_logger::fmt::Color::Blue
            }
        };
        style.set_color(color);
        if record.target().starts_with(crate_name!()) {
            writeln!(formatter, "{:<5} : {}",
                style.value(record.level()),
                style.value(record.args()))
        }
        else {
            let ts = chrono::Local::now().format("%FT%T%.6f%:z");
            writeln!(formatter, "{:<5} : [{}] [{}] {}",
                style.value(record.level()),
                ts,
                record.target(),
                style.value(record.args()))
        }
    });
    let write_filter = format!("{}={},{}",
        module_path!(),
        level,
        env::var("RUST_LOG").unwrap_or(String::from("")));
    builder.parse(&write_filter);
    builder.init();
}
