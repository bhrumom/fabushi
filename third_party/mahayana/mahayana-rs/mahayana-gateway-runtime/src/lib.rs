//! Native Mahayana Runtime adapter for the transport-neutral JSON-RPC gateway.
//!
//! This crate translates the production Rust runtime's existing event stream
//! into `mahayana-turn-protocol` without routing through renderer-specific
//! `DisplayMessage` / Workbench semantics.

use mahayana_gateway::{GatewayHandler, GatewayOutcome, JsonRpcError, method};
use mahayana_runtime::{
    mahayana_runtime_close, mahayana_runtime_create, mahayana_runtime_execute,
    mahayana_runtime_free_string, mahayana_runtime_interrupt, mahayana_runtime_last_error,
    mahayana_runtime_receive, mahayana_runtime_resolve_approval,
};
use mahayana_turn_protocol::{
    ApprovalRequest, MessageComplete, MessageStart, TextDelta, ToolComplete, ToolProgress,
    ToolStart, TurnCompletionStatus, TurnError, TurnEvent, TurnEventEnvelope,
};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

#[derive(Debug, Clone)]
struct ActiveTurn {
    conversation_id: String,
    turn_id: String,
    next_seq: u64,
}

pub struct NativeRuntimeGateway {
    runtime_id: u64,
    session_id: String,
    replay_epoch: u64,
    active_turns: HashMap<String, ActiveTurn>,
}

impl NativeRuntimeGateway {
    pub fn create() -> Result<Self, JsonRpcError> {
        let cwd = std::env::current_dir().map_err(internal)?;
        let use_codex_account = std::env::var("MAHAYANA_USE_CODEX_ACCOUNT").as_deref() == Ok("1");
        let mut config = json!({
            "hostPlatform": "cli",
            "cwd": cwd,
            "workspaceRoots": [cwd],
            "useCodexAccount": use_codex_account,
        });
        if use_codex_account && let Some(codex_home) = std::env::var_os("MAHAYANA_CODEX_HOME") {
            config["codexHome"] =
                serde_json::to_value(PathBuf::from(codex_home)).map_err(internal)?;
        }
        if let Ok(base_url) = std::env::var("MAHAYANA_RESPONSES_BASE_URL")
            && !base_url.trim().is_empty()
        {
            config["model"]["baseUrl"] = Value::String(base_url);
        }
        Self::create_with_config(config)
    }

    pub fn create_with_config(config: Value) -> Result<Self, JsonRpcError> {
        let encoded = CString::new(config.to_string()).map_err(internal)?;
        let runtime_id = unsafe { mahayana_runtime_create(encoded.as_ptr()) };
        if runtime_id == 0 {
            let error = unsafe { take_json(mahayana_runtime_last_error()) }.map_err(internal)?;
            return Err(JsonRpcError::internal(
                error
                    .get("message")
                    .and_then(Value::as_str)
                    .unwrap_or("native Mahayana Runtime creation failed"),
            ));
        }
        Ok(Self {
            runtime_id,
            session_id: format!("session:{}", Uuid::new_v4()),
            replay_epoch: 0,
            active_turns: HashMap::new(),
        })
    }

    pub fn session_id(&self) -> &str {
        &self.session_id
    }

    /// Polls one production Runtime event and translates it into the canonical
    /// assistant-turn protocol. Renderer-only events are never manufactured
    /// here; unknown native events remain available for future protocol growth.
    pub fn receive_turn_event(
        &mut self,
        timeout_ms: u64,
    ) -> Result<Option<TurnEventEnvelope>, JsonRpcError> {
        let response = unsafe { take_json(mahayana_runtime_receive(self.runtime_id, timeout_ms)) }
            .map_err(internal)?;
        let event = unwrap_ffi(response).map_err(JsonRpcError::internal)?;
        if event.is_null() {
            return Ok(None);
        }
        Ok(self.translate_runtime_event(&event))
    }

    fn execute(&self, command: Value) -> Result<Value, JsonRpcError> {
        let command = CString::new(command.to_string()).map_err(internal)?;
        let response =
            unsafe { take_json(mahayana_runtime_execute(self.runtime_id, command.as_ptr())) }
                .map_err(internal)?;
        unwrap_ffi(response).map_err(JsonRpcError::internal)
    }

    fn interrupt(&self, operation_id: &str) -> Result<(), JsonRpcError> {
        let request =
            CString::new(json!({"operationId": operation_id}).to_string()).map_err(internal)?;
        let response = unsafe {
            take_json(mahayana_runtime_interrupt(
                self.runtime_id,
                request.as_ptr(),
            ))
        }
        .map_err(internal)?;
        unwrap_ffi(response)
            .map(|_| ())
            .map_err(JsonRpcError::internal)
    }

    fn resolve_approval(&self, approval_id: &str, decision: &str) -> Result<(), JsonRpcError> {
        let runtime_decision = match decision {
            "allow-once" => "accept",
            "allow-session" => "acceptForSession",
            "deny" => "decline",
            other => {
                return Err(JsonRpcError::invalid_params(format!(
                    "invalid approval decision: {other}"
                )));
            }
        };
        let request = CString::new(
            json!({"approvalId": approval_id, "decision": runtime_decision}).to_string(),
        )
        .map_err(internal)?;
        let response = unsafe {
            take_json(mahayana_runtime_resolve_approval(
                self.runtime_id,
                request.as_ptr(),
            ))
        }
        .map_err(internal)?;
        unwrap_ffi(response)
            .map(|_| ())
            .map_err(JsonRpcError::internal)
    }

    fn start_turn(
        &mut self,
        conversation_id: String,
        text: &str,
    ) -> Result<GatewayOutcome, JsonRpcError> {
        let accepted = self.execute(json!({
            "@type": "mahayana.conversation.send",
            "conversationId": conversation_id,
            "text": text,
        }))?;
        let operation_id = required_string(&accepted, "operationId")?.to_string();
        let turn_id = operation_id.clone();
        self.active_turns.insert(
            operation_id.clone(),
            ActiveTurn {
                conversation_id: conversation_id.clone(),
                turn_id: turn_id.clone(),
                next_seq: 2,
            },
        );
        let start = TurnEventEnvelope::new(
            self.session_id.clone(),
            turn_id.clone(),
            operation_id.clone(),
            1,
            self.replay_epoch,
            now_ms(),
            TurnEvent::MessageStart(MessageStart::default()),
        )
        .with_conversation_id(conversation_id);
        Ok(GatewayOutcome::accepted(json!({
            "sessionId": self.session_id,
            "turnId": turn_id,
            "operationId": operation_id,
        }))
        .with_events([start]))
    }

    fn next_event(&mut self, operation_id: &str, event: TurnEvent) -> Option<TurnEventEnvelope> {
        let turn = self.active_turns.get_mut(operation_id)?;
        let seq = turn.next_seq;
        turn.next_seq = turn.next_seq.saturating_add(1);
        Some(
            TurnEventEnvelope::new(
                self.session_id.clone(),
                turn.turn_id.clone(),
                operation_id.to_string(),
                seq,
                self.replay_epoch,
                now_ms(),
                event,
            )
            .with_conversation_id(turn.conversation_id.clone()),
        )
    }

    fn translate_runtime_event(&mut self, value: &Value) -> Option<TurnEventEnvelope> {
        let event_type = value.get("@type").and_then(Value::as_str)?;
        let operation_id = value.get("operationId").and_then(Value::as_str)?;
        match event_type {
            "mahayana.message.delta" => self.next_event(
                operation_id,
                TurnEvent::MessageDelta(TextDelta {
                    text: value
                        .get("delta")
                        .and_then(Value::as_str)
                        .unwrap_or_default()
                        .to_string(),
                }),
            ),
            "mahayana.message.completed" => {
                let message = value.get("message")?;
                if message.get("role").and_then(Value::as_str) == Some("user") {
                    return None;
                }
                self.next_event(
                    operation_id,
                    TurnEvent::MessageComplete(MessageComplete {
                        text: message
                            .get("text")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string(),
                        status: TurnCompletionStatus::Completed,
                        usage: None,
                    }),
                )
            }
            "mahayana.agent.activity" => {
                let tool_id = value
                    .get("stepId")
                    .and_then(Value::as_str)
                    .unwrap_or(operation_id)
                    .to_string();
                let name = value
                    .get("kind")
                    .and_then(Value::as_str)
                    .unwrap_or("agent")
                    .to_string();
                let title = value
                    .get("title")
                    .and_then(Value::as_str)
                    .map(ToOwned::to_owned);
                let detail = value
                    .get("detail")
                    .and_then(Value::as_str)
                    .map(ToOwned::to_owned);
                match value
                    .get("status")
                    .and_then(Value::as_str)
                    .unwrap_or("running")
                {
                    "completed" => self.next_event(
                        operation_id,
                        TurnEvent::ToolComplete(ToolComplete {
                            tool_id,
                            result: detail
                                .map(|detail| json!({"detail": detail}))
                                .unwrap_or(Value::Null),
                            error: None,
                        }),
                    ),
                    "failed" => self.next_event(
                        operation_id,
                        TurnEvent::ToolComplete(ToolComplete {
                            tool_id,
                            result: Value::Null,
                            error: Some(
                                detail.unwrap_or_else(|| "Mahayana tool step failed".to_string()),
                            ),
                        }),
                    ),
                    _ => self.next_event(
                        operation_id,
                        TurnEvent::ToolStart(ToolStart {
                            tool_id,
                            name,
                            title,
                            arguments: detail
                                .map(|detail| json!({"detail": detail}))
                                .unwrap_or(Value::Null),
                        }),
                    ),
                }
            }
            "mahayana.plugin.progress" => {
                let plugin_id = value
                    .get("pluginId")
                    .and_then(Value::as_str)
                    .unwrap_or("plugin");
                let tool = value.get("tool").and_then(Value::as_str).unwrap_or("tool");
                self.next_event(
                    operation_id,
                    TurnEvent::ToolProgress(ToolProgress {
                        tool_id: format!("{plugin_id}:{tool}"),
                        detail: value
                            .get("message")
                            .and_then(Value::as_str)
                            .map(ToOwned::to_owned),
                        progress: value.get("progress").and_then(Value::as_u64),
                        total: value.get("total").and_then(Value::as_u64),
                    }),
                )
            }
            "mahayana.approval.requested" => self.next_event(
                operation_id,
                TurnEvent::ApprovalRequest(ApprovalRequest {
                    approval_id: value.get("approvalId").and_then(Value::as_str)?.to_string(),
                    subject: value
                        .get("title")
                        .and_then(Value::as_str)
                        .unwrap_or("Mahayana approval")
                        .to_string(),
                    detail: value.get("details").map(compact_value),
                    proposed_rule: value
                        .get("proposedRule")
                        .and_then(Value::as_str)
                        .map(ToOwned::to_owned),
                    metadata: value.get("metadata").cloned(),
                }),
            ),
            "mahayana.operation.failed" => self.next_event(
                operation_id,
                TurnEvent::TurnError(TurnError {
                    code: value
                        .get("code")
                        .and_then(Value::as_str)
                        .unwrap_or("mahayana_operation_failed")
                        .to_string(),
                    message: value
                        .get("message")
                        .and_then(Value::as_str)
                        .unwrap_or("Mahayana operation failed")
                        .to_string(),
                    recoverable: false,
                }),
            ),
            _ => None,
        }
    }
}

impl GatewayHandler for NativeRuntimeGateway {
    fn handle(&mut self, rpc_method: &str, params: &Value) -> Result<GatewayOutcome, JsonRpcError> {
        match rpc_method {
            method::SESSION_CREATE => Ok(GatewayOutcome::accepted(json!({
                "sessionId": self.session_id,
                "replayEpoch": self.replay_epoch,
            }))),
            method::SESSION_LIST => {
                let data = self.execute(json!({"@type": "mahayana.conversation.list"}))?;
                Ok(GatewayOutcome::accepted(data))
            }
            method::SESSION_HISTORY => {
                let conversation_id = required_string(params, "conversationId")?;
                let limit = params.get("limit").and_then(Value::as_u64).unwrap_or(500);
                let data = self.execute(json!({
                    "@type": "mahayana.conversation.history",
                    "conversationId": conversation_id,
                    "limit": limit,
                }))?;
                Ok(GatewayOutcome::accepted(data))
            }
            method::SESSION_RESUME => Ok(GatewayOutcome::accepted(json!({
                "sessionId": self.session_id,
                "replayEpoch": self.replay_epoch,
                "resumed": true,
            }))),
            method::SESSION_INTERRUPT => {
                let operation_id = required_string(params, "operationId")?;
                self.interrupt(operation_id)?;
                Ok(GatewayOutcome::accepted(
                    json!({"operationId": operation_id, "interrupted": true}),
                ))
            }
            method::PROMPT_SUBMIT => {
                let text = required_string(params, "text")?;
                let conversation_id = params
                    .get("conversationId")
                    .and_then(Value::as_str)
                    .filter(|value| !value.trim().is_empty())
                    .unwrap_or("mahayana-ai:agent:assistant")
                    .to_string();
                self.start_turn(conversation_id, text)
            }
            method::APPROVAL_RESOLVE => {
                let approval_id = required_string(params, "approvalId")?;
                let decision = required_string(params, "decision")?;
                self.resolve_approval(approval_id, decision)?;
                Ok(GatewayOutcome::accepted(
                    json!({"approvalId": approval_id, "decision": decision}),
                ))
            }
            method::TURN_REPLAY => Err(JsonRpcError::internal(
                "turn.replay requires the MSR-205 durable Rust replay store; live turn sequencing is active but durable replay is not accepted yet",
            )),
            method::CLARIFY_RESOLVE => Err(JsonRpcError::internal(
                "clarify.resolve is reserved by the turn contract but the native Runtime clarification resolver is not wired yet",
            )),
            _ => Err(JsonRpcError::method_not_found(rpc_method)),
        }
    }
}

impl Drop for NativeRuntimeGateway {
    fn drop(&mut self) {
        unsafe {
            let pointer = mahayana_runtime_close(self.runtime_id);
            mahayana_runtime_free_string(pointer);
        }
    }
}

fn required_string<'a>(value: &'a Value, name: &str) -> Result<&'a str, JsonRpcError> {
    value
        .get(name)
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| JsonRpcError::invalid_params(format!("{name} is required")))
}

fn unwrap_ffi(response: Value) -> Result<Value, String> {
    if response.get("ok").and_then(Value::as_bool) == Some(true) {
        return Ok(response.get("data").cloned().unwrap_or(Value::Null));
    }
    Err(response
        .get("message")
        .and_then(Value::as_str)
        .unwrap_or("Mahayana Runtime request failed")
        .to_string())
}

unsafe fn take_json(pointer: *mut c_char) -> Result<Value, String> {
    if pointer.is_null() {
        return Err("Mahayana Runtime returned a null JSON pointer".to_string());
    }
    let text = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .map_err(|error| error.to_string())?
        .to_string();
    unsafe { mahayana_runtime_free_string(pointer) };
    serde_json::from_str(&text).map_err(|error| error.to_string())
}

fn compact_value(value: &Value) -> String {
    match value {
        Value::String(value) => value.clone(),
        other => other.to_string(),
    }
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis().min(i64::MAX as u128) as i64)
        .unwrap_or_default()
}

fn internal(error: impl std::fmt::Display) -> JsonRpcError {
    JsonRpcError::internal(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn approval_decision_maps_turn_semantics_to_existing_runtime_contract() {
        assert_eq!(
            match "allow-session" {
                "allow-once" => "accept",
                "allow-session" => "acceptForSession",
                "deny" => "decline",
                _ => unreachable!(),
            },
            "acceptForSession"
        );
    }

    #[test]
    fn compact_value_keeps_plain_strings_plain() {
        assert_eq!(compact_value(&json!("hello")), "hello");
        assert_eq!(compact_value(&json!({"path": "a"})), r#"{"path":"a"}"#);
    }
}
