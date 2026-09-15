use clap::Parser;
use mahayana_core::{ApprovalDecision, RuntimeEvent};
use mahayana_gateway::{
    FfiRuntimeAdapter, GatewayRuntime, GatewayServer, InMemoryRuntime, RuntimeSubmitResult,
};
use mahayana_gateway_peer::{
    ServerRequestRegistry, ServerRequestResponse,
};
use mahayana_gateway_protocol::{
    ApprovalRequestPayload, GatewayEvent, GatewayEventEnvelope, JsonRpcEventNotification,
};
use serde_json::{Value, json};
use std::io::{self, BufRead, BufReader, Write};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

#[derive(Debug, Parser)]
#[command(
    name = "mahayana-gateway",
    about = "Run the first-party Mahayana JSON-RPC gateway"
)]
struct Cli {
    /// Serve line-delimited JSON-RPC over stdin/stdout.
    #[arg(long, default_value_t = false)]
    stdio: bool,

    /// Force the deterministic in-memory runtime. Production/Desktop should
    /// leave this false so the gateway connects to the native Mahayana runtime.
    #[arg(long, default_value_t = false)]
    in_memory: bool,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    if !cli.stdio {
        anyhow::bail!("mahayana-gateway currently requires --stdio");
    }

    if cli.in_memory {
        serve_stdio(InMemoryRuntime::default())?;
        return Ok(());
    }

    match FfiRuntimeAdapter::new() {
        Ok(runtime) => serve_stdio(runtime)?,
        Err(error) => {
            eprintln!(
                "warning: native Mahayana runtime unavailable ({error}); falling back to in-memory runtime"
            );
            serve_stdio(InMemoryRuntime::default())?;
        }
    }
    Ok(())
}

fn serve_stdio<R>(runtime: R) -> anyhow::Result<()>
where
    R: GatewayRuntime + 'static,
{
    let state = Arc::new(Mutex::new(GatewayServer::new(runtime)));
    let peer = Arc::new(Mutex::new(ServerRequestRegistry::default()));
    let stdout = Arc::new(Mutex::new(io::stdout()));

    let runtime_state = Arc::clone(&state);
    let runtime_peer = Arc::clone(&peer);
    let runtime_stdout = Arc::clone(&stdout);
    let _event_pump = thread::spawn(move || {
        loop {
            let runtime_events = match runtime_state.lock() {
                Ok(mut state) => state.runtime_mut().poll_events(50).unwrap_or_default(),
                Err(_) => break,
            };
            if runtime_events.is_empty() {
                thread::sleep(Duration::from_millis(20));
                continue;
            }
            for runtime_event in runtime_events {
                let projected = match runtime_state.lock() {
                    Ok(mut state) => state.ingest_runtime_event(runtime_event),
                    Err(_) => return,
                };
                let peer_frames = issue_server_requests(&runtime_peer, &projected);
                let Ok(mut writer) = runtime_stdout.lock() else {
                    return;
                };
                for event in projected {
                    let notification = JsonRpcEventNotification::new(event);
                    if writeln!(
                        writer,
                        "{}",
                        serde_json::to_string(&notification).unwrap_or_default()
                    )
                    .is_err()
                    {
                        return;
                    }
                }
                for frame in peer_frames {
                    if writeln!(writer, "{}", frame).is_err() {
                        return;
                    }
                }
                let _ = writer.flush();
            }
        }
    });

    let stdin = io::stdin();
    let reader = BufReader::new(stdin.lock());
    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let parsed = serde_json::from_str::<Value>(&line).ok();
        if let Some(frame) = parsed.as_ref()
            && ServerRequestRegistry::is_response_frame(frame)
        {
            if let Some(resolved) = peer
                .lock()
                .ok()
                .and_then(|mut peer| peer.resolve_response(frame))
            {
                resolve_peer_request(&state, resolved)?;
            }
            continue;
        }

        let legacy_approval_request_id = parsed
            .as_ref()
            .and_then(|frame| frame.get("method"))
            .and_then(Value::as_str)
            .filter(|method| *method == "approval.respond")
            .and_then(|_| parsed.as_ref()?.get("params"))
            .and_then(|params| params.get("requestId"))
            .and_then(Value::as_str)
            .map(ToOwned::to_owned);

        let response = state
            .lock()
            .map_err(|_| anyhow::anyhow!("gateway state poisoned"))?
            .handle_frame(&line);
        if let Some(response) = response {
            let mut writer = stdout
                .lock()
                .map_err(|_| anyhow::anyhow!("stdout lock poisoned"))?;
            writeln!(writer, "{}", serde_json::to_string(&response)?)?;
            writer.flush()?;

            if response.error.is_none()
                && let Some(request_id) = legacy_approval_request_id.as_deref()
            {
                close_peer_approval(&peer, request_id);
            }
        }
    }
    Ok(())
}

fn issue_server_requests(
    peer: &Arc<Mutex<ServerRequestRegistry>>,
    events: &[GatewayEventEnvelope],
) -> Vec<Value> {
    let Ok(mut peer) = peer.lock() else {
        return Vec::new();
    };
    let mut frames = Vec::new();
    for event in events {
        let GatewayEvent::ApprovalRequest(payload) = &event.event else {
            continue;
        };
        if pending_approval_exists(&peer, &payload.request_id) {
            continue;
        }
        let params = approval_params(payload);
        if let Ok(issued) = peer.issue(event.session_id.clone(), "approval", params) {
            frames.push(issued.frame);
        }
    }
    frames
}

fn approval_params(payload: &ApprovalRequestPayload) -> Value {
    json!({
        "requestId": payload.request_id,
        "title": payload.title,
        "description": payload.description,
        "toolId": payload.tool_id,
        "metadata": payload.metadata,
        "choices": ["allow-once", "allow-session", "deny"],
    })
}

fn pending_approval_exists(peer: &ServerRequestRegistry, request_id: &str) -> bool {
    peer.export_state().iter().any(|request| {
        request.method == "approval"
            && request.params.get("requestId").and_then(Value::as_str) == Some(request_id)
    })
}

fn close_peer_approval(peer: &Arc<Mutex<ServerRequestRegistry>>, request_id: &str) {
    let Ok(mut peer) = peer.lock() else {
        return;
    };
    let pending = peer.export_state().into_iter().find(|request| {
        request.method == "approval"
            && request.params.get("requestId").and_then(Value::as_str) == Some(request_id)
    });
    if let Some(request) = pending {
        let _ = peer.resolve_response(&json!({
            "jsonrpc": "2.0",
            "id": request.id,
            "result": {"decision": "resolved-by-approval.respond"},
        }));
    }
}

fn resolve_peer_request<R>(
    state: &Arc<Mutex<GatewayServer<R>>>,
    resolved: mahayana_gateway_peer::ResolvedServerRequest,
) -> anyhow::Result<()>
where
    R: GatewayRuntime + 'static,
{
    if resolved.request.method != "approval" {
        return Ok(());
    }
    let Some(request_id) = resolved
        .request
        .params
        .get("requestId")
        .and_then(Value::as_str)
    else {
        anyhow::bail!("approval server request is missing requestId");
    };

    let decision = match resolved.response {
        ServerRequestResponse::Result(result) => parse_approval_decision(&result),
        ServerRequestResponse::Error(_) => ApprovalDecision::Decline,
    };
    state
        .lock()
        .map_err(|_| anyhow::anyhow!("gateway state poisoned"))?
        .runtime_mut()
        .resolve_approval(request_id, decision)
        .map_err(anyhow::Error::msg)
}

fn parse_approval_decision(result: &Value) -> ApprovalDecision {
    match result.get("decision").and_then(Value::as_str) {
        Some("allow-once" | "accept") => ApprovalDecision::Accept,
        Some("allow-session" | "accept-for-session" | "acceptForSession") => {
            ApprovalDecision::AcceptForSession
        }
        _ => ApprovalDecision::Decline,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use mahayana_gateway_protocol::GatewayEventEnvelope;

    #[test]
    fn approval_event_emits_peer_request_with_same_runtime_request_id() {
        let peer = Arc::new(Mutex::new(ServerRequestRegistry::default()));
        let event = GatewayEventEnvelope::new(
            "session-1",
            "turn-1",
            1,
            "2026-09-15T00:00:00Z",
            "epoch-1",
            GatewayEvent::ApprovalRequest(ApprovalRequestPayload {
                request_id: "approval-1".to_string(),
                title: "Run shell".to_string(),
                description: Some("echo hello".to_string()),
                tool_id: Some("tool-1".to_string()),
                metadata: None,
            }),
        );
        let frames = issue_server_requests(&peer, &[event]);
        assert_eq!(frames.len(), 1);
        assert_eq!(frames[0]["method"], "approval");
        assert_eq!(frames[0]["params"]["requestId"], "approval-1");
        assert!(frames[0]["id"].as_str().unwrap().starts_with("srq-"));
    }

    #[test]
    fn repeated_approval_event_does_not_duplicate_peer_lock() {
        let peer = Arc::new(Mutex::new(ServerRequestRegistry::default()));
        let event = GatewayEventEnvelope::new(
            "session-1",
            "turn-1",
            1,
            "2026-09-15T00:00:00Z",
            "epoch-1",
            GatewayEvent::ApprovalRequest(ApprovalRequestPayload {
                request_id: "approval-1".to_string(),
                title: "Approve".to_string(),
                description: None,
                tool_id: None,
                metadata: None,
            }),
        );
        assert_eq!(issue_server_requests(&peer, &[event.clone()]).len(), 1);
        assert!(issue_server_requests(&peer, &[event]).is_empty());
    }

    #[test]
    fn peer_decision_maps_to_native_runtime_decision() {
        assert_eq!(
            parse_approval_decision(&json!({"decision": "allow-once"})),
            ApprovalDecision::Accept
        );
        assert_eq!(
            parse_approval_decision(&json!({"decision": "allow-session"})),
            ApprovalDecision::AcceptForSession
        );
        assert_eq!(
            parse_approval_decision(&json!({"decision": "deny"})),
            ApprovalDecision::Decline
        );
    }
}
