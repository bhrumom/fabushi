use mahayana_core::RuntimeEvent;
use mahayana_gateway::{
    GatewayRuntime, GatewayState, ReplayLimits, RpcFailure, dispatch_request,
};
use mahayana_gateway_protocol::JsonRpcEventNotification;
use mahayana_runtime::{
    mahayana_runtime_close, mahayana_runtime_create, mahayana_runtime_execute,
    mahayana_runtime_free_string, mahayana_runtime_interrupt, mahayana_runtime_last_error,
    mahayana_runtime_receive, mahayana_runtime_resolve_approval,
};
use serde_json::{Value, json};
use std::ffi::{CStr, CString};
use std::io::{self, BufRead, Write};
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

fn main() {
    if let Err(error) = run() {
        eprintln!("mahayana-gateway: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let runtime = Arc::new(Mutex::new(RuntimeHandle::create()?));
    let state = Arc::new(Mutex::new(GatewayState::new(ReplayLimits::default())));
    let output = Arc::new(Mutex::new(()));
    let shutdown = Arc::new(AtomicBool::new(false));

    let pump_runtime = Arc::clone(&runtime);
    let pump_state = Arc::clone(&state);
    let pump_output = Arc::clone(&output);
    let pump_shutdown = Arc::clone(&shutdown);
    let event_pump = thread::Builder::new()
        .name("mahayana-gateway-events".into())
        .spawn(move || {
            while !pump_shutdown.load(Ordering::Acquire) {
                let received = pump_runtime
                    .lock()
                    .map_err(|_| "runtime mutex poisoned".to_string())
                    .and_then(|runtime| runtime.receive(250));
                let raw_event = match received {
                    Ok(Some(event)) => event,
                    Ok(None) => continue,
                    Err(error) => {
                        eprintln!("mahayana-gateway runtime receive failed: {error}");
                        break;
                    }
                };
                let runtime_event = match serde_json::from_value::<RuntimeEvent>(raw_event) {
                    Ok(event) => event,
                    Err(error) => {
                        eprintln!("mahayana-gateway rejected malformed runtime event: {error}");
                        continue;
                    }
                };
                let projected = match pump_state.lock() {
                    Ok(mut state) => state.ingest_runtime_event(&runtime_event, now_ms()),
                    Err(_) => break,
                };
                for event in projected {
                    if write_notification(&pump_output, event).is_err() {
                        return;
                    }
                }
            }
        })
        .map_err(|error| error.to_string())?;

    for line in io::stdin().lock().lines() {
        let line = line.map_err(|error| error.to_string())?;
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let request = match serde_json::from_str::<Value>(line) {
            Ok(request) => request,
            Err(error) => {
                write_value(
                    &output,
                    &rpc_error(Value::Null, -32700, &format!("parse error: {error}")),
                )?;
                continue;
            }
        };
        if request.get("jsonrpc").and_then(Value::as_str) != Some("2.0") {
            let id = request.get("id").cloned().unwrap_or(Value::Null);
            write_value(&output, &rpc_error(id, -32600, "jsonrpc must be 2.0"))?;
            continue;
        }
        let id = request.get("id").cloned();
        let method = request
            .get("method")
            .and_then(Value::as_str)
            .unwrap_or_default();
        if method.is_empty() {
            let id = id.unwrap_or(Value::Null);
            write_value(&output, &rpc_error(id, -32600, "method is required"))?;
            continue;
        }
        let params = request.get("params").cloned().unwrap_or_else(|| json!({}));

        // Runtime -> state is the shared lock order used by the event pump too.
        // Holding both through prompt.submit prevents a fast runtime event from
        // racing ahead of turn/session registration.
        let dispatched = {
            let mut runtime = runtime
                .lock()
                .map_err(|_| "runtime mutex poisoned".to_string())?;
            let mut state = state
                .lock()
                .map_err(|_| "gateway state mutex poisoned".to_string())?;
            dispatch_request(method, &params, &mut *runtime, &mut state, now_ms())
        };

        match dispatched {
            Ok(dispatched) => {
                // RPC acknowledgement is written before semantic events so a
                // client can bind its turn id before message.start arrives.
                if let Some(id) = id {
                    write_value(&output, &rpc_result(id, dispatched.result))?;
                }
                for event in dispatched.events {
                    write_notification(&output, event)?;
                }
            }
            Err(RpcFailure { code, message }) => {
                if let Some(id) = id {
                    write_value(&output, &rpc_error(id, code, message.as_str()))?;
                }
            }
        }

        if method == "gateway.shutdown" {
            break;
        }
    }

    shutdown.store(true, Ordering::Release);
    let _ = event_pump.join();
    Ok(())
}

fn rpc_result(id: Value, result: Value) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "result": result })
}

fn rpc_error(id: Value, code: i64, message: &str) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": { "code": code, "message": message },
    })
}

fn write_notification(
    output: &Arc<Mutex<()>>,
    event: mahayana_gateway_protocol::GatewayEventEnvelope,
) -> Result<(), String> {
    let value = serde_json::to_value(JsonRpcEventNotification::new(event))
        .map_err(|error| error.to_string())?;
    write_value(output, &value)
}

fn write_value(output: &Arc<Mutex<()>>, value: &Value) -> Result<(), String> {
    let _guard = output
        .lock()
        .map_err(|_| "stdout mutex poisoned".to_string())?;
    let stdout = io::stdout();
    let mut stdout = stdout.lock();
    serde_json::to_writer(&mut stdout, value).map_err(|error| error.to_string())?;
    stdout.write_all(b"\n").map_err(|error| error.to_string())?;
    stdout.flush().map_err(|error| error.to_string())
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or(Duration::ZERO)
        .as_millis()
        .min(i64::MAX as u128) as i64
}

struct RuntimeHandle(u64);

impl RuntimeHandle {
    fn create() -> Result<Self, String> {
        let cwd = std::env::current_dir().map_err(|error| error.to_string())?;
        let use_codex_account = std::env::var("MAHAYANA_USE_CODEX_ACCOUNT").as_deref() == Ok("1");
        let mut config = json!({
            "codexExecutablePath": Value::Null,
            "hostPlatform": "cli",
            "cwd": cwd,
            "workspaceRoots": [cwd],
            "useCodexAccount": use_codex_account,
        });
        if use_codex_account
            && let Some(codex_home) = std::env::var_os("MAHAYANA_CODEX_HOME")
        {
            config["codexHome"] = serde_json::to_value(PathBuf::from(codex_home))
                .map_err(|error| error.to_string())?;
        }
        if let Ok(base_url) = std::env::var("MAHAYANA_RESPONSES_BASE_URL")
            && !base_url.trim().is_empty()
        {
            config["model"] = json!({ "baseUrl": base_url });
        }
        let config = CString::new(config.to_string()).map_err(|error| error.to_string())?;
        let id = unsafe { mahayana_runtime_create(config.as_ptr()) };
        if id == 0 {
            let error = unsafe { take_json(mahayana_runtime_last_error()) }?;
            return Err(error
                .get("message")
                .and_then(Value::as_str)
                .unwrap_or("Mahayana runtime creation failed")
                .to_string());
        }
        Ok(Self(id))
    }

    fn execute_value(&self, command: Value) -> Result<Value, String> {
        let command = CString::new(command.to_string()).map_err(|error| error.to_string())?;
        let response = unsafe { take_json(mahayana_runtime_execute(self.0, command.as_ptr())) }?;
        unwrap_ffi(response)
    }

    fn receive(&self, timeout_ms: u64) -> Result<Option<Value>, String> {
        let response = unsafe { take_json(mahayana_runtime_receive(self.0, timeout_ms)) }?;
        let data = unwrap_ffi(response)?;
        if data.is_null() {
            Ok(None)
        } else {
            Ok(Some(data))
        }
    }

    fn interrupt_value(&self, turn_id: &str) -> Result<Value, String> {
        let request = CString::new(json!({ "operationId": turn_id }).to_string())
            .map_err(|error| error.to_string())?;
        let response = unsafe { take_json(mahayana_runtime_interrupt(self.0, request.as_ptr())) }?;
        unwrap_ffi(response)
    }

    fn resolve_approval_value(&self, approval_id: &str, decision: &str) -> Result<Value, String> {
        let request = CString::new(
            json!({ "approvalId": approval_id, "decision": decision }).to_string(),
        )
        .map_err(|error| error.to_string())?;
        let response = unsafe {
            take_json(mahayana_runtime_resolve_approval(self.0, request.as_ptr()))
        }?;
        unwrap_ffi(response)
    }
}

impl GatewayRuntime for RuntimeHandle {
    fn execute(&mut self, command: Value) -> Result<Value, String> {
        self.execute_value(command)
    }

    fn interrupt(&mut self, turn_id: &str) -> Result<Value, String> {
        self.interrupt_value(turn_id)
    }

    fn resolve_approval(&mut self, approval_id: &str, decision: &str) -> Result<Value, String> {
        self.resolve_approval_value(approval_id, decision)
    }
}

impl Drop for RuntimeHandle {
    fn drop(&mut self) {
        unsafe {
            let pointer = mahayana_runtime_close(self.0);
            mahayana_runtime_free_string(pointer);
        }
    }
}

fn unwrap_ffi(response: Value) -> Result<Value, String> {
    if response.get("ok").and_then(Value::as_bool) == Some(true) {
        Ok(response.get("data").cloned().unwrap_or(Value::Null))
    } else {
        Err(response
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("Mahayana runtime call failed")
            .to_string())
    }
}

unsafe fn take_json(pointer: *mut c_char) -> Result<Value, String> {
    if pointer.is_null() {
        return Err("Mahayana runtime returned a null pointer".into());
    }
    let source = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .map_err(|error| error.to_string())?
        .to_string();
    unsafe { mahayana_runtime_free_string(pointer) };
    serde_json::from_str(&source).map_err(|error| error.to_string())
}
