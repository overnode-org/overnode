
use std;
use std::io::Read;

use std::io::{BufReader, BufRead};

use errors;
use errors::ResultExt;

pub struct ProcessResult {
    pub stdout: String,
    pub stderr: String,
    pub exit_code: i32
}

pub fn run_process_non_interactively(command: &str, args: Vec<&str>) -> errors::Result<ProcessResult> {
    let error_message = format!("failure to spawn child process: {}", command);
    let mut child: std::process::Child = std::process::Command::new(command)
        .args(args)
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .chain_err(move || error_message)?;

    let error_message = format!("failure to wait child process: {}", command);
    let ecode = child.wait()
        .chain_err(move || error_message)?;

    let mut out_contents = String::new();
    for out in &mut child.stdout {
        let error_message = format!("failure to read stdout");
        out.read_to_string(&mut out_contents).chain_err(move || error_message)?;
    }

    let mut err_contents = String::new();
    for err in &mut child.stderr {
        let error_message = format!("failure to read stderr");
        err.read_to_string(&mut err_contents).chain_err(move || error_message)?;
    }

    Ok(ProcessResult {
        stdout: out_contents,
        stderr: err_contents,
        exit_code: ecode.code().unwrap_or(-1)
    })
}

pub fn run_process_interactively(command: &str, args: Vec<&str>) -> errors::Result<ProcessResult> {
    let error_message = format!("failure to spawn child process: {}", command);
    let mut child: std::process::Child = std::process::Command::new(command)
        .args(args)
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .chain_err(move || error_message)?;

    loop {

        let mut out_contents = String::new();
        for out in &mut child.stderr {
            let mut stdout_reader = BufReader::new(out);
            let stdout_line = stdout_reader.read_line(&mut out_contents);
            info!("{}", out_contents);

//            let error_message = format!("failure to read stdout");
//            out.read_line(&mut out_contents).chain_err(move || error_message)?;
        }

        let maybe_exit_code = child.try_wait()
            .chain_err(move || format!("failure to wait child process"))?;
        if maybe_exit_code.is_some() {
            break;
        }
    }

    let error_message = format!("failure to wait child process: {}", command);
    let ecode = child.wait()
        .chain_err(move || error_message)?;

    let mut out_contents = String::new();
    for out in &mut child.stdout {
        let error_message = format!("failure to read stdout");
        out.read_to_string(&mut out_contents).chain_err(move || error_message)?;
    }

    let mut err_contents = String::new();
    for err in &mut child.stderr {
        let error_message = format!("failure to read stderr");
        err.read_to_string(&mut err_contents).chain_err(move || error_message)?;
    }

    Ok(ProcessResult {
        stdout: out_contents,
        stderr: err_contents,
        exit_code: ecode.code().unwrap_or(-1)
    })
}
