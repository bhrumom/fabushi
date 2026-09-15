//! Mahayana's transport-neutral gateway dispatcher.
//!
//! The same request dispatcher and turn-event notification encoder is intended
//! to sit behind CLI stdio and application-host WebSocket/native transports.
//! Transport adapters own bytes and connection lifecycle; this crate owns RPC
//! semantics so Desktop and CLI cannot silently drift into different agents.

use mahayana_turn_protocol::TurnEventEnvelope;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::io::{BufRead, Write};

pub const JSON_RPC_VERSION: &str = "2.0";
pub const EVENT_NOTIFICATION_METHOD: &str = "event";

pub mod method {
    pub const SESSION_CREATE: &str = "session.create";
    pub const SESSION_LIST: &str = "session.list";
    pub const SESSION_HISTORY: &str = "session.history";
    pub const SESSION_RESUME: &str = "session.resume";
    pub const SESSION_INTERRUPT: &str = "session.interrupt";
    pub const PROMPT_SUBMIT: &str = "prompt.submit";
    pub const TURN_REPLAY: &str = "turn.replay";
    pub const APPROVAL_RESOLVE: &str = "approval.resolve";
    pub const CLARIFY_RESOLVE: &str = "clarify.resolve";

    pub const CATALOG: &[&str] = &[
        SESSION_CREATE,
        SESSION_LIST,
        SESSION_HISTORY,
        SESSION_RESUME,
        SESSION_INTERRUPT,
        PROMPT_SUBMIT,
        TURN_REPLAY,
        APPROVAL_RESOLVE,
        CLARIFY_RESOLVE,
    ];
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub id: Option<Value>,
    pub method: String,
    #[serde(default)]
    pub params: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct JsonRpcResponse {
    pub jsonrpc: &'static str,
    pub id: Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<JsonRpcError>,
}

impl JsonRpcResponse {
    pub fn success(id: Value, result: Value) -> Self {
        Self {
            jsonrpc: JSON_RPC_VERSION,
            id,
            result: Some(result),
            error: None,
        }
    }

    pub fn failure(id: Value, error: JsonRpcError) -> Self {
        Self {
            jsonrpc: JSON_RPC_VERSION,
            id,
            result: None,
            error: Some(error),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JsonRpcError {
    pub code: i64,
    pub message: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

impl JsonRpcError {
    pub fn invalid_request(message: impl Into<String>) -> Self {
        Self { code: -32600, message: message.into(), data: None }
    }

    pub fn method_not_found(method: impl Into<String>) -> Self {
        let method = method.into();
        Self {
            code: -32601,
            message: format!("method not found: {method}"),
            data: Some(Value::String(method)),
        }
    }

    pub fn invalid_params(message: impl Into<String>) -> Self {
        Self { code: -32602, message: message.into(), data: None }
    }

    pub fn internal(message: impl Into<String>) -> Self {
        Self { code: -32603, message: message.into(), data: None }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct GatewayOutcome {
    pub result: Value,
    pub events: Vec<TurnEventEnvelope>,
}

impl GatewayOutcome {
    pub fn accepted(result: Value) -> Self {
        Self { result, events: Vec::new() }
    }

    pub fn with_events(mut self, events: impl IntoIterator<Item = TurnEventEnvelope>) -> Self {
        self.events.extend(events);
        self
    }
}

pub trait GatewayHandler {
    fn handle(&mut self, method: &str, params: &Value) -> Result<GatewayOutcome, JsonRpcError>;
}

#[derive(Debug, Clone, PartialEq)]
pub struct DispatchResult {
    pub response: Option<JsonRpcResponse>,
    pub events: Vec<TurnEventEnvelope>,
}

pub struct GatewayDispatcher<H> {
    handler: H,
}

impl<H> GatewayDispatcher<H>
where
    H: GatewayHandler,
{
    pub fn new(handler: H) -> Self {
        Self { handler }
    }

    pub fn handler(&self) -> &H {
        &self.handler
    }

    pub fn handler_mut(&mut self) -> &mut H {
        &mut self.handler
    }

    pub fn dispatch_json(&mut self, input: &str) -> DispatchResult {
        let request: JsonRpcRequest = match serde_json::from_str(input) {
            Ok(request) => request,
            Err(error) => {
                return DispatchResult {
                    response: Some(JsonRpcResponse::failure(
                        Value::Null,
                        JsonRpcError::invalid_request(error.to_string()),
                    )),
                    events: Vec::new(),
                };
            }
        };
        self.dispatch(request)
    }

    pub fn dispatch(&mut self, request: JsonRpcRequest) -> DispatchResult {
        if request.jsonrpc != JSON_RPC_VERSION {
            return DispatchResult {
                response: request.id.map(|id| JsonRpcResponse::failure(
                    id,
                    JsonRpcError::invalid_request("jsonrpc must be 2.0"),
                )),
                events: Vec::new(),
            };
        }
        if request.method.trim().is_empty() {
            return DispatchResult {
                response: request.id.map(|id| JsonRpcResponse::failure(
                    id,
                    JsonRpcError::invalid_request("method must not be empty"),
                )),
                events: Vec::new(),
            };
        }

        let outcome = self.handler.handle(&request.method, &request.params);
        match outcome {
            Ok(outcome) => DispatchResult {
                response: request.id.map(|id| JsonRpcResponse::success(id, outcome.result)),
                events: outcome.events,
            },
            Err(error) => DispatchResult {
                response: request.id.map(|id| JsonRpcResponse::failure(id, error)),
                events: Vec::new(),
            },
        }
    }
}

#[derive(Debug, Serialize)]
struct EventNotification<'a> {
    jsonrpc: &'static str,
    method: &'static str,
    params: &'a TurnEventEnvelope,
}

pub fn event_notification(event: &TurnEventEnvelope) -> Result<String, serde_json::Error> {
    serde_json::to_string(&EventNotification {
        jsonrpc: JSON_RPC_VERSION,
        method: EVENT_NOTIFICATION_METHOD,
        params: event,
    })
}

/// Line-delimited JSON-RPC stdio adapter. A WebSocket/native adapter should
/// feed frames through `GatewayDispatcher::dispatch` and encode turn events
/// with `event_notification`, preserving the exact same method/event semantics.
pub fn serve_stdio<R, W, H>(reader: R, mut writer: W, handler: H) -> std::io::Result<H>
where
    R: BufRead,
    W: Write,
    H: GatewayHandler,
{
    let mut dispatcher = GatewayDispatcher::new(handler);
    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let dispatched = dispatcher.dispatch_json(&line);
        if let Some(response) = dispatched.response {
            serde_json::to_writer(&mut writer, &response).map_err(std::io::Error::other)?;
            writer.write_all(b"\n")?;
        }
        for event in dispatched.events {
            let notification = event_notification(&event).map_err(std::io::Error::other)?;
            writer.write_all(notification.as_bytes())?;
            writer.write_all(b"\n")?;
        }
        writer.flush()?;
    }
    Ok(dispatcher.handler)
}

#[cfg(test)]
mod tests {
    use super::*;
    use mahayana_turn_protocol::{MessageStart, TurnEvent, TurnEventEnvelope};
    use serde_json::json;
    use std::collections::VecDeque;
    use std::io::Cursor;

    #[derive(Default)]
    struct TestHandler {
        calls: VecDeque<String>,
    }

    impl GatewayHandler for TestHandler {
        fn handle(&mut self, method: &str, params: &Value) -> Result<GatewayOutcome, JsonRpcError> {
            if !method::CATALOG.contains(&method) {
                return Err(JsonRpcError::method_not_found(method));
            }
            self.calls.push_back(method.to_owned());
            let operation_id = params.get("operationId").and_then(Value::as_str).unwrap_or("operation-1");
            Ok(GatewayOutcome::accepted(json!({ "accepted": true, "operationId": operation_id })).with_events([
                TurnEventEnvelope::new(
                    "session-1",
                    operation_id,
                    operation_id,
                    1,
                    0,
                    1_000,
                    TurnEvent::MessageStart(MessageStart::default()),
                ),
            ]))
        }
    }

    #[test]
    fn dispatcher_returns_rpc_result_and_same_turn_event_contract() {
        let mut dispatcher = GatewayDispatcher::new(TestHandler::default());
        let dispatched = dispatcher.dispatch_json(&json!({
            "jsonrpc": "2.0",
            "id": 42,
            "method": "prompt.submit",
            "params": { "operationId": "turn-42", "text": "hello" }
        }).to_string());
        assert_eq!(dispatched.response.unwrap().result.unwrap()["operationId"], "turn-42");
        assert_eq!(dispatched.events.len(), 1);
        assert_eq!(dispatched.events[0].operation_id, "turn-42");
        assert_eq!(dispatched.events[0].event_type(), "message.start");
    }

    #[test]
    fn notification_uses_json_rpc_event_method() {
        let event = TurnEventEnvelope::new(
            "session-1",
            "turn-1",
            "turn-1",
            1,
            0,
            1_000,
            TurnEvent::MessageStart(MessageStart::default()),
        );
        let value: Value = serde_json::from_str(&event_notification(&event).unwrap()).unwrap();
        assert_eq!(value["jsonrpc"], "2.0");
        assert_eq!(value["method"], "event");
        assert_eq!(value["params"]["type"], "message.start");
    }

    #[test]
    fn stdio_and_frame_dispatch_share_the_same_dispatcher_semantics() {
        let input = concat!(
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"session.create\",\"params\":{}}\n",
            "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"prompt.submit\",\"params\":{\"operationId\":\"turn-2\"}}\n"
        );
        let mut output = Vec::new();
        let handler = serve_stdio(Cursor::new(input.as_bytes()), &mut output, TestHandler::default()).unwrap();
        assert_eq!(handler.calls.into_iter().collect::<Vec<_>>(), vec!["session.create", "prompt.submit"]);

        let lines = String::from_utf8(output).unwrap();
        let frames = lines.lines().map(|line| serde_json::from_str::<Value>(line).unwrap()).collect::<Vec<_>>();
        assert_eq!(frames.len(), 4, "each request produces one response and one event notification");
        assert_eq!(frames[0]["id"], 1);
        assert_eq!(frames[1]["method"], "event");
        assert_eq!(frames[2]["id"], 2);
        assert_eq!(frames[3]["params"]["operationId"], "turn-2");
    }
}
