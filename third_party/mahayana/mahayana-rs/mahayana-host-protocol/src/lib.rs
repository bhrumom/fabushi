//! Versioned product-level commands and events shared by React, Tauri, mobile
//! shells, deterministic tests, and future WebAssembly hosts.

use serde::Deserialize;
use serde::Serialize;

pub const HOST_PROTOCOL_VERSION: &str = "1";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum HostMode {
    Test,
    Production,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HostConfig {
    pub profile_id: String,
    pub mode: HostMode,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SurfacePlatform {
    Mock,
    Tauri,
    Wasm,
    Flutter,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HostInfo {
    pub runtime_version: String,
    pub protocol_version: String,
    pub platform: SurfacePlatform,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum FeatureCommand {
    #[serde(rename = "chat.send")]
    ChatSend {
        #[serde(rename = "requestId")]
        request_id: String,
        text: String,
    },
    #[serde(rename = "marketplace.install")]
    MarketplaceInstall {
        #[serde(rename = "requestId")]
        request_id: String,
        #[serde(rename = "miniAppId")]
        mini_app_id: String,
    },
    #[serde(rename = "miniapp.open")]
    MiniAppOpen {
        #[serde(rename = "requestId")]
        request_id: String,
        #[serde(rename = "miniAppId")]
        mini_app_id: String,
    },
    #[serde(rename = "capability.request")]
    CapabilityRequest {
        #[serde(rename = "requestId")]
        request_id: String,
        #[serde(rename = "miniAppId")]
        mini_app_id: String,
        capability: String,
        reason: String,
    },
    #[serde(rename = "runtime.longTask")]
    RuntimeLongTask {
        #[serde(rename = "requestId")]
        request_id: String,
        label: String,
    },
    #[serde(rename = "session.clear")]
    SessionClear {
        #[serde(rename = "requestId")]
        request_id: String,
    },
}

impl FeatureCommand {
    pub fn request_id(&self) -> &str {
        match self {
            Self::ChatSend { request_id, .. }
            | Self::MarketplaceInstall { request_id, .. }
            | Self::MiniAppOpen { request_id, .. }
            | Self::CapabilityRequest { request_id, .. }
            | Self::RuntimeLongTask { request_id, .. }
            | Self::SessionClear { request_id } => request_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CommandAccepted {
    pub request_id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub operation_id: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ApprovalDecision {
    AllowOnce,
    Deny,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalResolution {
    pub approval_id: String,
    pub decision: ApprovalDecision,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MessageRole {
    User,
    Assistant,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum HostEvent {
    #[serde(rename = "host.ready")]
    HostReady {
        timestamp: String,
        info: HostInfo,
    },
    #[serde(rename = "chat.message")]
    ChatMessage {
        timestamp: String,
        role: MessageRole,
        text: String,
    },
    #[serde(rename = "marketplace.installed")]
    MarketplaceInstalled {
        timestamp: String,
        #[serde(rename = "miniAppId")]
        mini_app_id: String,
        version: String,
    },
    #[serde(rename = "miniapp.opened")]
    MiniAppOpened {
        timestamp: String,
        #[serde(rename = "miniAppId")]
        mini_app_id: String,
    },
    #[serde(rename = "approval.requested")]
    ApprovalRequested {
        timestamp: String,
        #[serde(rename = "approvalId")]
        approval_id: String,
        #[serde(rename = "miniAppId")]
        mini_app_id: String,
        capability: String,
        reason: String,
    },
    #[serde(rename = "approval.resolved")]
    ApprovalResolved {
        timestamp: String,
        #[serde(rename = "approvalId")]
        approval_id: String,
        decision: ApprovalDecision,
    },
    #[serde(rename = "operation.started")]
    OperationStarted {
        timestamp: String,
        #[serde(rename = "operationId")]
        operation_id: String,
        label: String,
        interruptible: bool,
    },
    #[serde(rename = "operation.interrupted")]
    OperationInterrupted {
        timestamp: String,
        #[serde(rename = "operationId")]
        operation_id: String,
    },
    #[serde(rename = "session.cleared")]
    SessionCleared { timestamp: String },
    #[serde(rename = "host.closed")]
    HostClosed { timestamp: String },
}

impl HostEvent {
    pub fn kind(&self) -> &'static str {
        match self {
            Self::HostReady { .. } => "host.ready",
            Self::ChatMessage { .. } => "chat.message",
            Self::MarketplaceInstalled { .. } => "marketplace.installed",
            Self::MiniAppOpened { .. } => "miniapp.opened",
            Self::ApprovalRequested { .. } => "approval.requested",
            Self::ApprovalResolved { .. } => "approval.resolved",
            Self::OperationStarted { .. } => "operation.started",
            Self::OperationInterrupted { .. } => "operation.interrupted",
            Self::SessionCleared { .. } => "session.cleared",
            Self::HostClosed { .. } => "host.closed",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn command_json_is_compatible_with_the_react_contract() {
        let command: FeatureCommand = serde_json::from_str(
            r#"{"type":"capability.request","requestId":"req-1","miniAppId":"global-dharma","capability":"camera","reason":"scan scripture"}"#,
        )
        .expect("decode command");
        assert_eq!(command.request_id(), "req-1");
        assert_eq!(
            serde_json::to_value(command).expect("encode command")["type"],
            "capability.request"
        );
    }

    #[test]
    fn event_json_uses_camel_case_fields() {
        let event = HostEvent::OperationStarted {
            timestamp: "0".into(),
            operation_id: "operation-1".into(),
            label: "sync".into(),
            interruptible: true,
        };
        let value = serde_json::to_value(event).expect("encode event");
        assert_eq!(value["type"], "operation.started");
        assert_eq!(value["operationId"], "operation-1");
    }
}
