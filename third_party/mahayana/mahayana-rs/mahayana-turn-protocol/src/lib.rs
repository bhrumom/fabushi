//! Transport-neutral assistant-turn events shared by Mahayana CLI, desktop,
//! mobile, web and replay/persistence layers.
//!
//! The contract intentionally models one logical assistant turn as an ordered
//! stream of fine-grained events. UI surfaces project this stream into message
//! parts; they do not become the authority for execution state.

use serde::{Deserialize, Serialize};
use serde_json::Value;

pub const TURN_PROTOCOL_VERSION: u16 = 1;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TurnEventEnvelope {
    pub protocol_version: u16,
    pub session_id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub conversation_id: Option<String>,
    pub turn_id: String,
    pub operation_id: String,
    pub seq: u64,
    pub replay_epoch: u64,
    pub timestamp_ms: i64,
    #[serde(flatten)]
    pub event: TurnEvent,
}

impl TurnEventEnvelope {
    pub fn new(
        session_id: impl Into<String>,
        turn_id: impl Into<String>,
        operation_id: impl Into<String>,
        seq: u64,
        replay_epoch: u64,
        timestamp_ms: i64,
        event: TurnEvent,
    ) -> Self {
        Self {
            protocol_version: TURN_PROTOCOL_VERSION,
            session_id: session_id.into(),
            conversation_id: None,
            turn_id: turn_id.into(),
            operation_id: operation_id.into(),
            seq,
            replay_epoch,
            timestamp_ms,
            event,
        }
    }

    pub fn with_conversation_id(mut self, conversation_id: impl Into<String>) -> Self {
        self.conversation_id = Some(conversation_id.into());
        self
    }

    pub fn event_type(&self) -> &'static str {
        self.event.event_type()
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum TurnEvent {
    #[serde(rename = "message.start")]
    MessageStart(MessageStart),
    #[serde(rename = "message.delta")]
    MessageDelta(TextDelta),
    #[serde(rename = "message.interim")]
    MessageInterim(TextBlock),
    #[serde(rename = "message.complete")]
    MessageComplete(MessageComplete),
    #[serde(rename = "reasoning.delta")]
    ReasoningDelta(ReasoningDelta),
    #[serde(rename = "reasoning.available")]
    ReasoningAvailable(TextBlock),
    #[serde(rename = "tool.generating")]
    ToolGenerating(ToolGenerating),
    #[serde(rename = "tool.start")]
    ToolStart(ToolStart),
    #[serde(rename = "tool.progress")]
    ToolProgress(ToolProgress),
    #[serde(rename = "tool.complete")]
    ToolComplete(ToolComplete),
    #[serde(rename = "approval.request")]
    ApprovalRequest(ApprovalRequest),
    #[serde(rename = "approval.resolve")]
    ApprovalResolve(ApprovalResolve),
    #[serde(rename = "clarify.request")]
    ClarifyRequest(ClarifyRequest),
    #[serde(rename = "clarify.resolve")]
    ClarifyResolve(ClarifyResolve),
    #[serde(rename = "subagent.start")]
    SubagentStart(SubagentStart),
    #[serde(rename = "subagent.progress")]
    SubagentProgress(SubagentProgress),
    #[serde(rename = "subagent.complete")]
    SubagentComplete(SubagentComplete),
    #[serde(rename = "artifact.available")]
    ArtifactAvailable(ArtifactAvailable),
    #[serde(rename = "turn.error")]
    TurnError(TurnError),
}

impl TurnEvent {
    pub const fn event_type(&self) -> &'static str {
        match self {
            Self::MessageStart(_) => "message.start",
            Self::MessageDelta(_) => "message.delta",
            Self::MessageInterim(_) => "message.interim",
            Self::MessageComplete(_) => "message.complete",
            Self::ReasoningDelta(_) => "reasoning.delta",
            Self::ReasoningAvailable(_) => "reasoning.available",
            Self::ToolGenerating(_) => "tool.generating",
            Self::ToolStart(_) => "tool.start",
            Self::ToolProgress(_) => "tool.progress",
            Self::ToolComplete(_) => "tool.complete",
            Self::ApprovalRequest(_) => "approval.request",
            Self::ApprovalResolve(_) => "approval.resolve",
            Self::ClarifyRequest(_) => "clarify.request",
            Self::ClarifyResolve(_) => "clarify.resolve",
            Self::SubagentStart(_) => "subagent.start",
            Self::SubagentProgress(_) => "subagent.progress",
            Self::SubagentComplete(_) => "subagent.complete",
            Self::ArtifactAvailable(_) => "artifact.available",
            Self::TurnError(_) => "turn.error",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct MessageStart {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub provider: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TextDelta {
    pub text: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TextBlock {
    pub text: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MessageComplete {
    pub text: String,
    #[serde(default)]
    pub status: TurnCompletionStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub usage: Option<Value>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum TurnCompletionStatus {
    #[default]
    Completed,
    Interrupted,
    Error,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReasoningDelta {
    pub text: String,
    #[serde(default)]
    pub replace: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolGenerating {
    pub tool_id: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolStart {
    pub tool_id: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(default)]
    pub arguments: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolProgress {
    pub tool_id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub progress: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub total: Option<u64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolComplete {
    pub tool_id: String,
    #[serde(default)]
    pub result: Value,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalRequest {
    pub approval_id: String,
    pub subject: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub proposed_rule: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ApprovalDecision {
    AllowOnce,
    AllowSession,
    Deny,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalResolve {
    pub approval_id: String,
    pub decision: ApprovalDecision,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClarifyRequest {
    pub request_id: String,
    pub prompt: String,
    #[serde(default)]
    pub options: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClarifyResolve {
    pub request_id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub value: Option<Value>,
    #[serde(default)]
    pub dismissed: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SubagentStart {
    pub subagent_id: String,
    pub label: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub agent_type: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SubagentProgress {
    pub subagent_id: String,
    pub detail: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SubagentComplete {
    pub subagent_id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub summary: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ArtifactAvailable {
    pub artifact_id: String,
    pub title: String,
    pub kind: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub uri: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TurnError {
    pub code: String,
    pub message: String,
    #[serde(default)]
    pub recoverable: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn envelope_serializes_stable_coordinates_and_event_name() {
        let event = TurnEventEnvelope::new(
            "session-1",
            "turn-1",
            "operation-1",
            7,
            2,
            42,
            TurnEvent::MessageDelta(TextDelta {
                text: "hello".into(),
            }),
        )
        .with_conversation_id("conversation-1");

        let value = serde_json::to_value(event).unwrap();
        assert_eq!(value["protocolVersion"], TURN_PROTOCOL_VERSION);
        assert_eq!(value["sessionId"], "session-1");
        assert_eq!(value["conversationId"], "conversation-1");
        assert_eq!(value["turnId"], "turn-1");
        assert_eq!(value["operationId"], "operation-1");
        assert_eq!(value["seq"], 7);
        assert_eq!(value["replayEpoch"], 2);
        assert_eq!(value["type"], "message.delta");
        assert_eq!(value["payload"]["text"], "hello");
    }

    #[test]
    fn tool_lifecycle_keeps_one_stable_tool_identity() {
        let start = TurnEvent::ToolStart(ToolStart {
            tool_id: "tool-9".into(),
            name: "github.search".into(),
            title: Some("Search repository".into()),
            arguments: json!({"q": "message.delta"}),
        });
        let complete = TurnEvent::ToolComplete(ToolComplete {
            tool_id: "tool-9".into(),
            result: json!({"matches": 3}),
            error: None,
        });

        assert_eq!(start.event_type(), "tool.start");
        assert_eq!(complete.event_type(), "tool.complete");
        let start_value = serde_json::to_value(start).unwrap();
        let complete_value = serde_json::to_value(complete).unwrap();
        assert_eq!(
            start_value["payload"]["toolId"],
            complete_value["payload"]["toolId"]
        );
    }

    #[test]
    fn approval_decision_uses_existing_product_semantics() {
        let value = serde_json::to_value(ApprovalResolve {
            approval_id: "approval-1".into(),
            decision: ApprovalDecision::AllowSession,
        })
        .unwrap();
        assert_eq!(value["decision"], "allow-session");
    }
}
