
use std;
use std::fs::File;
use std::io::Write;
use std::ops::Deref;

use serde_json;
use serde_yaml;

use errors;
use errors::ResultExt;

use process;

#[derive(Serialize, Deserialize, Debug)]
#[serde(deny_unknown_fields)]
pub enum VolumeConfigurationType {
    #[serde(rename = "bind")]
    Bind,
    #[serde(rename = "tmpfs")]
    Tmpfs,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(deny_unknown_fields)]
pub struct VolumeConfigurationMap {
    #[serde(rename = "type")]
    #[serde(skip_serializing_if = "Option::is_none")]
    kind: Option<VolumeConfigurationType>,
    source: String,
    target: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    read_only: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    consistency: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    bind: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    volume: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    tmpfs: Option<serde_json::Value>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(deny_unknown_fields)]
pub struct ServiceConfigurationMap {
    #[serde(skip_serializing_if = "Option::is_none")]
    cap_add: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    cap_drop: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    cgroup_parent: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    command: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    devices: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    domainname: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    entrypoint: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    environment: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    extra_hosts: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    healthcheck: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    hostname: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    image: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ipc: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    labels: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    links: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    logging: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pid: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ports: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    privileged: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    read_only: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    restart: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    security_opt: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    shm_size: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    sysctls: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    stdin_open: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    stop_grace_period: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    stop_signal: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    tmpfs: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    tty: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ulimits: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    user: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    volumes: Option<Vec<VolumeConfigurationMap>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    working_dir: Option<serde_json::Value>
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(deny_unknown_fields)]
pub struct Configuration {
    version: String,
    services: std::collections::HashMap<String, ServiceConfigurationMap>
}

pub fn validate_config(config: &Configuration) -> errors::Result<()> {
    let valid_versions: Vec<&str> = vec!["3", "3.0", "3.1", "3.2", "3.3", "3.4", "3.5", "3.6"];
    if !valid_versions.contains(&&config.version.deref()) {
        return Err(format!("version '{}' is invalid, expected 3 or 3.0 - 3.6", config.version).into())
    }
    for (key, srv) in &config.services {
        for volumes in &srv.volumes {
            for (ind, volume) in volumes.iter().enumerate() {
                let source = &volume.source;
                if !source.starts_with("/") {
                    return Err(format!("services.{}.volumes[{}].source '{}' \
                    is not an absolute path", key, ind, source).into())
                }
            }
        }
    }

    info!("validating with docker-compose");
    let mut file: File = File::create("./tmp.yaml")
        .chain_err(|| format!("failure to create temporary file ./tmp.yaml"))?;
    write!(&mut file, "{}", serde_yaml::to_string(&config).unwrap())
        .chain_err(|| "failure to write to temporary file ./tmp.yaml")?;
    let process_result: process::ProcessResult = process::run_process_non_interactively(
        "docker-compose", vec!("-f", "./tmp.yaml", "config")
    )?;

    if process_result.exit_code != 0 {
        let lines: Vec<&str> = process_result.stderr.split("\n").collect();
        let error_message = lines[1..].join("\n");
        return Err(error_message.into())
    }

    info!("up");
    let process_result: process::ProcessResult = process::run_process_interactively(
        "docker-compose", vec!("-f", "./tmp.yaml", "up", "-d")
    )?;

    return Ok(())
}
