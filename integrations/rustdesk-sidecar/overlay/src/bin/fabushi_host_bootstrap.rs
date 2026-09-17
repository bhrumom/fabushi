// SPDX-License-Identifier: AGPL-3.0-only
// Local-only bridge to the installed RustDesk daemon IPC. This process never
// accepts network connections and never receives Fabushi account credentials.

use serde::Deserialize;
use serde_json::{json, Value};
use std::io::{self, BufRead, Write};

const PROTOCOL: &str = "fabushi.rustdesk-host-bootstrap.v1";
const MAX_LINE_BYTES: usize = 64 * 1024;

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase", deny_unknown_fields)]
enum Command {
    Hello { protocol: String },
    HostInfo,
    RotateTemporaryPassword,
}

fn config(name: &str) -> Result<String, String> {
    librustdesk::ipc::get_config(name)
        .map_err(|error| format!("ipc:{error}"))?
        .filter(|value| !value.is_empty())
        .ok_or_else(|| format!("missing-{name}"))
}

fn host_info(include_password: bool) -> Result<Value, String> {
    let peer_id = config("id")?;
    if peer_id.len() > 160 || !peer_id.bytes().all(|b| b.is_ascii_alphanumeric() || b"._:-".contains(&b)) {
        return Err("invalid-peer-id".into());
    }
    let mut value = json!({"protocol": PROTOCOL, "type": "hostInfo", "peerId": peer_id});
    if include_password {
        let password = config("temporary-password")?;
        if password.len() < 6 || password.len() > 32 || password.bytes().any(|b| b.is_ascii_whitespace() || b.is_ascii_control()) {
            return Err("invalid-temporary-password".into());
        }
        value["temporaryPassword"] = Value::String(password);
    }
    Ok(value)
}

fn handle(command: Command) -> Result<Value, String> {
    match command {
        Command::Hello { protocol } => {
            if protocol != PROTOCOL { return Err("protocol-mismatch".into()); }
            Ok(json!({"protocol": PROTOCOL, "type": "hello", "control": "local-ipc", "capabilities": ["peerId", "rotateTemporaryPassword"]}))
        }
        Command::HostInfo => host_info(false),
        Command::RotateTemporaryPassword => {
            librustdesk::ipc::update_temporary_password().map_err(|error| format!("ipc:{error}"))?;
            host_info(true)
        }
    }
}

fn emit(value: Value) {
    let mut stdout = io::stdout().lock();
    let _ = serde_json::to_writer(&mut stdout, &value);
    let _ = stdout.write_all(b"\n");
    let _ = stdout.flush();
}

fn main() {
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = match line {
            Ok(line) => line,
            Err(error) => { emit(json!({"protocol": PROTOCOL, "type": "error", "code": format!("stdin:{error}")})); break; }
        };
        if line.len() > MAX_LINE_BYTES {
            emit(json!({"protocol": PROTOCOL, "type": "error", "code": "command-too-large"}));
            continue;
        }
        match serde_json::from_str::<Command>(&line).map_err(|error| format!("invalid-command:{error}")).and_then(handle) {
            Ok(value) => emit(value),
            Err(code) => emit(json!({"protocol": PROTOCOL, "type": "error", "code": code})),
        }
    }
}
