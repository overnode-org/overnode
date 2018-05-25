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

use std::io::Write;
use std::ops::Deref;
use std::fs::File;
use std::io::Read;

use errors::ResultExt;

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
            .default_value("warn")
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
        debug!("finished with result: {:?}", result);
        return result
    }

    return app.print_help().chain_err(|| "failure to print help message")
}

#[derive(Serialize, Deserialize, Debug)]
enum ConfigVersion {
    #[serde(rename = "3")]
    Three,
    #[serde(rename = "3.0")]
    ThreeZero,
    #[serde(rename = "3.1")]
    ThreeOnce,
    #[serde(rename = "3.2")]
    ThreeTwo,
    #[serde(rename = "3.3")]
    ThreeThree,
    #[serde(rename = "3.4")]
    ThreeFour,
    #[serde(rename = "3.5")]
    ThreeFive,
    #[serde(rename = "3.6")]
    ThreeSix,
}

#[derive(Serialize, Deserialize, Debug)]
enum ConfigVolumeType {
    #[serde(rename = "bind")]
    Bind,
    #[serde(rename = "tmpfs")]
    Tmpfs,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(deny_unknown_fields)]
struct ConfigVolume {
    #[serde(rename = "type")]
    kind: Option<ConfigVolumeType>,
    source: String,
    target: String,
    read_only: Option<serde_json::Value>,
    consistency: Option<serde_json::Value>,
    bind: Option<serde_json::Value>,
    volume: Option<serde_json::Value>,
    tmpfs: Option<serde_json::Value>,
}

#[derive(Serialize, Deserialize, Debug)]
enum ConfigVolumeEither {
    Short(String),
    Long(ConfigVolume)
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(deny_unknown_fields)]
struct ConfigService {
    cap_add: Option<serde_json::Value>,
    cap_drop: Option<serde_json::Value>,
    cgroup_parent: Option<serde_json::Value>,
    command: Option<serde_json::Value>,
    devices: Option<serde_json::Value>,
    domainname: Option<serde_json::Value>,
    entrypoint: Option<serde_json::Value>,
    environment: Option<serde_json::Value>,
    extra_hosts: Option<serde_json::Value>,
    healthcheck: Option<serde_json::Value>,
    hostname: Option<serde_json::Value>,
    image: Option<serde_json::Value>,
    ipc: Option<serde_json::Value>,
    labels: Option<serde_json::Value>,
    links: Option<serde_json::Value>,
    logging: Option<serde_json::Value>,
    pid: Option<serde_json::Value>,
    ports: Option<serde_json::Value>,
    privileged: Option<serde_json::Value>,
    read_only: Option<serde_json::Value>,
    restart: Option<serde_json::Value>,
    security_opt: Option<serde_json::Value>,
    shm_size: Option<serde_json::Value>,
    sysctls: Option<serde_json::Value>,
    stdin_open: Option<serde_json::Value>,
    stop_grace_period: Option<serde_json::Value>,
    stop_signal: Option<serde_json::Value>,
    tmpfs: Option<serde_json::Value>,
    tty: Option<serde_json::Value>,
    ulimits: Option<serde_json::Value>,
    user: Option<serde_json::Value>,
    volumes: Option<Vec<ConfigVolumeEither>>,
    working_dir: Option<serde_json::Value>
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(deny_unknown_fields)]
struct Config {
    version: ConfigVersion,
    services: std::collections::HashMap<String, ConfigService>
}

fn run_apply(config_path: String) -> errors::Result<()> {

    let error_message = format!("failure to open configuration file {}", config_path.clone());
    let mut file = File::open(config_path.clone()).chain_err(move || error_message)?;

    let mut contents = String::new();
    let error_message = format!("failure to read configuration file {}", config_path.clone());
    file.read_to_string(&mut contents).chain_err(move || error_message)?;

    let error_message = format!("configuration file '{}' is invalid", config_path.clone());
    let config: Config = serde_yaml::from_str(&contents).chain_err(move || error_message)?;

    let mut file: File = File::create("./tmp.yaml")
        .chain_err(|| format!("failure to create temporary file ./tmp.yaml"))?;

    write!(&mut file, "{}", contents)
        .chain_err(|| "failure to write to temporary file ./tmp.yaml")?;

    let error_message = format!("configuration file '{}' is invalid", config_path.clone());
    validate_config(&config).chain_err(move || error_message)?;

    return Ok(());
}

fn validate_config(config: &Config) -> errors::Result<()> {
    for (key, srv) in &config.services {
        for v in srv.volumes.as_ref() {

        }
    }
    return Err("not implemented".into())
}

fn init_logging(quite: bool, level: &str, color_style: &str) -> () {
    if quite {
        return;
    }

    let mut builder = env_logger::Builder::new();
    let write_style = std::env::var("RUST_LOG_STYLE").unwrap_or(String::from(color_style));
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
        if record.target() == crate_name!() {
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
        std::env::var("RUST_LOG").unwrap_or(String::from("")));
    builder.parse(&write_filter);
    builder.init();
}
