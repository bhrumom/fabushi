#[path = "../gateway.rs"]
mod gateway;

use gateway::GATEWAY_PROTOCOL_VERSION;
use gateway::GatewayState;
use gateway::ReplayLimits;
use gateway::event_notification;
use mahayana_core::RuntimeEvent;
use mahayana_runtime::mahayana_runtime_close;
use mahayana_runtime::mahayana_runtime_create;
use mahayana_runtime::mahayana_runtime_execute;
use mahayana_runtime::mahayana_runtime_free_string;
use mahayana_runtime::mahayana_runtime_interrupt;
use mahayana_runtime::mahayana_runtime_last_error;
use mahayana_runtime::mahayana_runtime_receive;
use mahayana_runtime::mahayana_runtime_resolve_approval;
use serde_json::Value;
use serde_json::json;
use std::ffi::CStr;
use std::ffi::CString;
use std::io;
use std::io::BufRead;
use std::io::Write;
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::thread;
use std::time::Duration;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

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

    let replay_epoch = state
        .lock()
        .map_err(|_| "gateway state mutex poisoned".to_string())?
        .replay_epoch()
        .to_string();
    write_value(
        &output,
        &json!({
            "jsonrpc": "2.0",
            "method": "event",
            "params": {
                "protocol_version": GATEWAY_PROTOCOL_VERSION,
                "replay_epoch": replay_epoch,
                "type": "gateway.ready",
                "heartbeat": true,
            }
        }),
    )?;

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
                let event = match received {
                    Ok(Some(event)) => event,
                    Ok(None) => continue,
                    Err(error) => {
                        let _ = write_value(
                            &pump_output,
                            &json!({
                                "jsonrpc": "2.0",
                                "method": "event",
                                "params": {
                                    "protocol_version": GATEWAY_PROTOCOL_VERSION,
                                    "type": "gateway.error",
                                    "message": error,
                                }
                            }),
                        );
                        break;
                    }
                };

                let runtime_event = match serde_json::from_value::<RuntimeEvent>(event.clone()) {
                    Ok(event) => event,
                    Err(error) => {
                        let _ = write_value(
                            &pump_output,
                            &json!({
                                "jsonrpc": "2.0",
                                "method": "event",
                                "params": {
                                    "protocol_version": GATEWAY_PROTOCOL_VERSION,
                                    "type": "gateway.protocol_error",
                                    "message": error.to_string(),
                                    "runtimeEvent": event,
                                }
                            }),
                        );
                        continue;
                    }
                };

                let projected = match pump_state.lock() {
                    Ok(mut state) => state.ingest_runtime_event(&runtime_event, now_ms()),
                    Err(_) => break,
                };
                for event in projected {
                    if write_value(&pump_output, &event_notification(&event)).is_err() {
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
        let id = request.get("id").cloned();
        let method = request.get("method").and_then(Value::as_str).unwrap_or_default();
        let params = request
            .get("params")
            .cloned()
            .unwrap_or_else(|| json!({}));
        let response = match handle_request(method, &params, &runtime, &state, &output) {
            Ok(result) => id.clone().map(|id| rpc_result(id, result)),
            Err(error) => id
                .clone()
                .map(|id| rpc_error(id, error.code, error.message.as_str())),
        };
        if let Some(response) = response {
            write_value(&output, &response)?;
        }
        if method == "gateway.shutdown" {
            break;
        }
    }

    shutdown.store(true, Ordering::Release);
    let _ = event_pump.join();
    Ok(())
}

struct RpcFailure {
    code: i64,
    message: String,
}

impl RpcFailure {
    fn invalid(message: impl Into<String>) -> Self {
        Self {
            code: -32602,
            message: message.into(),
        }
    }

    fn internal(message: impl Into<String>) -> Self {
        Self {
            code: -32603,
            message: message.into(),
        }
    }
}

fn handle_request(
    method: &str,
    params: &Value,
    runtime: &Arc<Mutex<RuntimeHandle>>,
    state: &Arc<Mutex<GatewayState>>,
    output: &Arc<Mutex<()>>,
) -> Result<Value, RpcFailure> {
    match method {
        "gateway.info" => {
            let state = state
                .lock()
                .map_err(|_| RpcFailure::internal("gateway state mutex poisoned"))?;
            Ok(json!({
                "protocol_version": GATEWAY_PROTOCOL_VERSION,
                "replay_epoch": state.replay_epoch(),
                "transport": "stdio",
                "runtime": "mahayana",
            }))
        }
        "gateway.shutdown" => Ok(json!({ "shutting_down": true })),
        "prompt.submit" => {
            let session_id = string_param(params, "session_id", "sessionId")?;
            let text = params
                .get("text")
                .and_then(Value::as_str)
                .filter(|text| !text.trim().is_empty())
                .ok_or_else(|| RpcFailure::invalid("prompt.submit requires non-empty text"))?;

            // Keep receive() out until the accepted operation has been bound to
            // its session. A very fast model cannot race completion ahead of the
            // turn/session registration.
            let (turn_id, start_event) = {
                let runtime = runtime
                    .lock()
                    .map_err(|_| RpcFailure::internal("runtime mutex poisoned"))?;
                let accepted = runtime
                    .execute(json!({
                        "@type": "mahayana.conversation.send",
                        "conversationId": session_id,
                        "text": text,
                    }))
                    .map_err(RpcFailure::internal)?;
                let turn_id = accepted
                    .get("operationId")
                    .and_then(Value::as_str)
                    .ok_or_else(|| RpcFailure::internal("runtime did not return operationId"))?
                    .to_string();
                let mut state = state
                    .lock()
                    .map_err(|_| RpcFailure::internal("gateway state mutex poisoned"))?;
                state.register_turn(turn_id.clone(), session_id.to_string());
                let start_event = state.emit(
                    session_id,
                    turn_id.as_str(),
                    now_ms(),
                    "message.start",
                    json!({}),
                );
                (turn_id, start_event)
            };
            write_value(output, &event_notification(&start_event)).map_err(RpcFailure::internal)?;
            Ok(json!({ "session_id": session_id, "turn_id": turn_id }))
        }
        "session.list" => runtime_execute(
            runtime,
            json!({ "@type": "mahayana.conversation.list" }),
        ),
        "session.history" => {
            let session_id = string_param(params, "session_id", "sessionId")?;
            let limit = params
                .get("limit")
                .and_then(Value::as_u64)
                .unwrap_or(100)
                .clamp(1, 500);
            runtime_execute(
                runtime,
                json!({
                    "@type": "mahayana.conversation.history",
                    "conversationId": session_id,
                    "limit": limit,
                }),
            )
        }
        "session.interrupt" => {
            let turn_id = string_param(params, "turn_id", "turnId")?;
            runtime
                .lock()
                .map_err(|_| RpcFailure::internal("runtime mutex poisoned"))?
                .interrupt(turn_id)
                .map_err(RpcFailure::internal)
        }
        "approval.respond" => {
            let approval_id = string_param(params, "approval_id", "approvalId")?;
            let decision = params
                .get("decision")
                .and_then(Value::as_str)
                .ok_or_else(|| RpcFailure::invalid("approval.respond requires decision"))?;
            if !matches!(decision, "accept" | "acceptForSession" | "decline" | "cancel") {
                return Err(RpcFailure::invalid(
                    "decision must be accept, acceptForSession, decline, or cancel",
                ));
            }
            runtime
                .lock()
                .map_err(|_| RpcFailure::internal("runtime mutex poisoned"))?
                .resolve_approval(approval_id, decision)
                .map_err(RpcFailure::internal)
        }
        "session.events.since" => {
            let session_id = string_param(params, "session_id", "sessionId")?;
            let last_seen = params
                .get("last_seen")
                .or_else(|| params.get("lastSeen"))
                .and_then(Value::as_u64)
                .unwrap_or_default();
            let expected_epoch = params
                .get("replay_epoch")
                .or_else(|| params.get("replayEpoch"))
                .and_then(Value::as_str);
            let state = state
                .lock()
                .map_err(|_| RpcFailure::internal("gateway state mutex poisoned"))?;
            if expected_epoch.is_some_and(|epoch| epoch != state.replay_epoch()) {
                return Ok(json!({
                    "replay_epoch": state.replay_epoch(),
                    "session_id": session_id,
                    "last_seen": last_seen,
                    "latest_seq": state.replay_since(session_id, 0).latest_seq,
                    "truncated": true,
                    "reset": true,
                    "events": [],
                }));
            }
            Ok(state.replay_since(session_id, last_seen).to_value())
        }
        _ => Err(RpcFailure {
            code: -32601,
            message: format!("method not found: {method}"),
        }),
    }
}

fn runtime_execute(
    runtime: &Arc<Mutex<RuntimeHandle>>,
    command: Value,
) -> Result<Value, RpcFailure> {
    runtime
        .lock()
        .map_err(|_| RpcFailure::internal("runtime mutex poisoned"))?
        .execute(command)
        .map_err(RpcFailure::internal)
}

fn string_param<'a>(params: &'a Value, snake: &str, camel: &str) -> Result<&'a str, RpcFailure> {
    params
        .get(snake)
        .or_else(|| params.get(camel))
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| RpcFailure::invalid(format!("missing {snake}")))
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
        if use_codex_account && let Some(codex_home) = std::env::var_os("MAHAYANA_CODEX_HOME") {
            config["codexHome"] = serde_json::to_value(PathBuf::from(codex_home))
                .map_err(|error| error.to_string())?;
        }
        if let Ok(base_url) = std::env::var("MAHAYANA_RESPONSES_BASE_URL")
            && !base_url.trim().is_empty()
        {
            config["model"]["baseUrl"] = Value::String(base_url);
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

    fn execute(&self, command: Value) -> Result<Value, String> {
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

    fn interrupt(&self, turn_id: &str) -> Result<Value, String> {
        let request = CString::new(json!({ "operationId": turn_id }).to_string())
            .map_err(|error| error.to_string())?;
        let response = unsafe { take_json(mahayana_runtime_interrupt(self.0, request.as_ptr())) }?;
        unwrap_ffi(response)
    }

    fn resolve_approval(&self, approval_id: &str, decision: &str) -> Result<Value, String> {
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
