//! Provider-neutral Agent abstraction used by the Mahayana conversation runtime.

use async_trait::async_trait;
use mahayana_core::AgentThreadId;
use mahayana_core::ApprovalDecision;
use mahayana_core::ApprovalId;
use mahayana_core::ConversationId;
use mahayana_core::Message;
use mahayana_core::ModelTokenUsageSnapshot;
use mahayana_core::OperationId;
use mahayana_core::capability::kernel::BackendCapabilities;
use mahayana_platform_core::HostPlatform;
use serde_json::Value;
use std::collections::BTreeMap;
use std::collections::HashMap;
use std::sync::Arc;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentActivityStatus {
    Running,
    Completed,
    Failed,
}

#[derive(Debug, Clone)]
pub struct AgentActivity {
    pub step_id: String,
    pub kind: String,
    pub title: String,
    pub detail: Option<String>,
    pub status: AgentActivityStatus,
    /// Original structured provider item when available. Product hosts use this
    /// for rich surfaces such as subagent/task state without reverse-parsing
    /// presentation strings. Generic backends may leave it absent.
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone)]
pub struct StartThreadRequest {
    pub conversation_id: ConversationId,
}

#[derive(Debug, Clone)]
pub struct OpenMcpAppRequest {
    pub conversation_id: ConversationId,
    pub plugin_id: String,
    pub platform: HostPlatform,
}

#[derive(Debug, Clone)]
pub struct McpAppSession {
    pub thread_id: AgentThreadId,
    pub plugin_id: String,
    pub server: String,
    pub command_tools: HashMap<String, String>,
    /// MCP tool name to server-authoritative entitlement capability. The host
    /// checks this immediately before the tool call; plugins never decide
    /// whether their own paid capability is unlocked.
    pub tool_gates: HashMap<String, String>,
    pub tools: Vec<Value>,
    pub home_result: Value,
    pub ui_resources: Vec<Value>,
}

#[derive(Debug, Clone)]
pub struct AgentMessageRequest {
    pub thread_id: AgentThreadId,
    pub conversation_id: ConversationId,
    pub operation_id: OperationId,
    pub text: String,
    pub client_message_id: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ApprovalResolution {
    pub approval_id: ApprovalId,
    pub decision: ApprovalDecision,
    pub payload: Value,
}

#[derive(Debug, Clone)]
pub enum AgentEvent {
    MessageDelta {
        delta: String,
    },
    MessageCompleted {
        message: Message,
    },
    /// Provider-reported usage projected into the Mahayana token contract.
    TokenUsageUpdated {
        usage: ModelTokenUsageSnapshot,
    },
    /// Progress reported by a tool while the containing turn is still running.
    ToolProgress {
        message: String,
    },
    /// Structured turn item used by desktop/mobile activity timelines. It
    /// intentionally carries a presentation-safe summary rather than a
    /// provider-specific protocol payload.
    Activity {
        activity: AgentActivity,
    },
    ApprovalRequested {
        approval_id: ApprovalId,
        title: String,
        details: Value,
    },
}

/// Receives streaming output from an [`AgentBackend`]. Implementations must be
/// inexpensive and thread-safe because model runtimes may call them for every
/// token delta.
pub trait AgentEventSink: Send + Sync {
    fn emit(&self, event: AgentEvent) -> Result<(), AgentError>;
}

pub type SharedAgentEventSink = Arc<dyn AgentEventSink>;

/// In-process AI engine boundary. Codex, Grok-derived implementations, local
/// models, and future Mahayana-native engines all implement this same contract.
#[async_trait]
pub trait AgentBackend: Send + Sync {
    async fn start_thread(&self, request: StartThreadRequest) -> Result<AgentThreadId, AgentError>;

    async fn send_message(
        &self,
        request: AgentMessageRequest,
        events: SharedAgentEventSink,
    ) -> Result<(), AgentError>;

    async fn interrupt(&self, operation_id: &OperationId) -> Result<(), AgentError>;

    async fn resolve_approval(&self, resolution: ApprovalResolution) -> Result<(), AgentError>;

    /// Declares features implemented by this backend. The default is empty so
    /// compatibility adapters remain source-compatible until they opt in.
    fn capabilities(&self) -> BackendCapabilities {
        BackendCapabilities::default()
    }

    /// Returns the live MCP server inventory owned by the agent runtime.
    async fn list_mcp_servers(&self) -> Result<Vec<Value>, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not expose MCP server status".into(),
        ))
    }

    /// Returns the Apps/Connector directory including accessibility and install
    /// URLs when that capability is enabled for the current account.
    async fn list_connector_apps(&self) -> Result<Vec<Value>, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not expose the connector directory".into(),
        ))
    }

    /// Starts the native MCP OAuth flow and returns the authorization URL.
    async fn mcp_oauth_login(&self, _server: &str) -> Result<String, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not support MCP OAuth".into(),
        ))
    }

    /// Removes locally stored OAuth credentials for one MCP server.
    async fn mcp_oauth_logout(&self, _server: &str) -> Result<bool, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not support MCP OAuth logout".into(),
        ))
    }

    /// Removes a user-managed MCP server configuration. Plugin-provided or
    /// otherwise read-only servers must return false rather than mutating their source.
    async fn remove_mcp_server(&self, _server: &str) -> Result<bool, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not support MCP configuration removal".into(),
        ))
    }

    /// Returns per-server Fabushi instructions that must be applied whenever
    /// the model uses that MCP server's tools.
    async fn mcp_custom_instructions(&self) -> Result<HashMap<String, String>, AgentError> {
        Ok(HashMap::new())
    }

    /// Persists per-server custom instructions without exposing provider credentials.
    async fn set_mcp_custom_instructions(
        &self,
        _server: &str,
        _instructions: &str,
    ) -> Result<(), AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not support MCP custom instructions".into(),
        ))
    }

    /// Changes the actual runtime tool deny-list for a user-managed MCP server.
    async fn set_mcp_tool_disabled(
        &self,
        _server: &str,
        _tool: &str,
        _disabled: bool,
    ) -> Result<Vec<String>, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not support MCP tool filtering".into(),
        ))
    }

    /// Reloads configured MCP servers after credentials or plugin state change.
    async fn refresh_mcp_servers(&self) -> Result<(), AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not support MCP refresh".into(),
        ))
    }

    /// Calls one tool on a configured MCP server through a dedicated,
    /// tool-isolated agent thread. Implementations must not expose shell,
    /// filesystem, web, or unrelated MCP servers to this thread.
    async fn call_mcp_tool(
        &self,
        _server: &str,
        _tool: &str,
        _arguments: Value,
    ) -> Result<Value, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not support direct MCP tool calls".into(),
        ))
    }

    /// Opens a tool-isolated MCP App thread. Backends must expose only this
    /// server's MCP tools and no general shell/filesystem tools for the returned
    /// thread.
    async fn open_mcp_app(&self, _request: OpenMcpAppRequest) -> Result<McpAppSession, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not host MCP Apps".into(),
        ))
    }

    async fn list_mcp_app_tools(
        &self,
        _thread_id: &AgentThreadId,
        _server: &str,
    ) -> Result<Vec<Value>, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not host MCP Apps".into(),
        ))
    }

    async fn call_mcp_app_tool(
        &self,
        _thread_id: &AgentThreadId,
        _server: &str,
        _tool: &str,
        _arguments: Value,
    ) -> Result<Value, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not host MCP Apps".into(),
        ))
    }

    /// Reads a display resource from the MCP server that owns this mini-app
    /// session. Hosts must not inject returned article text into model context
    /// unless the user explicitly asks for it.
    async fn read_mcp_app_resource(
        &self,
        _thread_id: &AgentThreadId,
        _server: &str,
        _uri: &str,
    ) -> Result<Vec<Value>, AgentError> {
        Err(AgentError::Unavailable(
            "this agent backend does not host MCP App resources".into(),
        ))
    }

    fn name(&self) -> &'static str;
}

/// Registered backend plus product-owned routing priority.
#[derive(Clone)]
pub struct BackendRegistration {
    pub id: String,
    pub priority: i32,
    pub backend: Arc<dyn AgentBackend>,
}

/// Mahayana-owned backend registry. It selects an implementation by declared
/// capability rather than by vendor name, which keeps routing independent from
/// Codex/Grok protocol types.
#[derive(Default)]
pub struct BackendRegistry {
    backends: BTreeMap<String, BackendRegistration>,
}

impl BackendRegistry {
    pub fn register(
        &mut self,
        id: impl Into<String>,
        priority: i32,
        backend: Arc<dyn AgentBackend>,
    ) -> Result<(), AgentError> {
        let id = id.into();
        if id.trim().is_empty() {
            return Err(AgentError::InvalidBackendId);
        }
        if self.backends.contains_key(&id) {
            return Err(AgentError::DuplicateBackend(id));
        }
        self.backends.insert(
            id.clone(),
            BackendRegistration {
                id,
                priority,
                backend,
            },
        );
        Ok(())
    }

    pub fn get(&self, id: &str) -> Option<Arc<dyn AgentBackend>> {
        self.backends.get(id).map(|entry| Arc::clone(&entry.backend))
    }

    pub fn select(&self, required: BackendCapabilities) -> Option<Arc<dyn AgentBackend>> {
        self.backends
            .values()
            .filter(|entry| backend_supports(entry.backend.capabilities(), required))
            .max_by(|left, right| {
                left.priority
                    .cmp(&right.priority)
                    .then_with(|| right.id.cmp(&left.id))
            })
            .map(|entry| Arc::clone(&entry.backend))
    }

    pub fn descriptors(&self) -> Vec<BackendDescriptor> {
        self.backends
            .values()
            .map(|entry| BackendDescriptor {
                id: entry.id.clone(),
                priority: entry.priority,
                implementation: entry.backend.name().to_string(),
                capabilities: entry.backend.capabilities(),
            })
            .collect()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BackendDescriptor {
    pub id: String,
    pub priority: i32,
    pub implementation: String,
    pub capabilities: BackendCapabilities,
}

pub fn backend_supports(
    available: BackendCapabilities,
    required: BackendCapabilities,
) -> bool {
    (!required.realtime || available.realtime)
        && (!required.tools || available.tools)
        && (!required.web || available.web)
        && (!required.mcp || available.mcp)
        && (!required.sandbox || available.sandbox)
        && (!required.subagents || available.subagents)
        && (!required.checkpoints || available.checkpoints)
        && (!required.headless || available.headless)
        && (!required.hooks || available.hooks)
        && (!required.skills || available.skills)
}

#[derive(Debug, thiserror::Error)]
pub enum AgentError {
    #[error("agent backend is unavailable: {0}")]
    Unavailable(String),
    #[error("agent backend id must not be empty")]
    InvalidBackendId,
    #[error("agent backend is already registered: {0}")]
    DuplicateBackend(String),
    #[error("agent thread was not found: {0}")]
    ThreadNotFound(AgentThreadId),
    #[error("agent operation was not found: {0}")]
    OperationNotFound(OperationId),
    #[error("agent approval was not found: {0}")]
    ApprovalNotFound(ApprovalId),
    #[error("model usage limit exceeded: {0}")]
    UsageLimitExceeded(String),
    #[error("agent backend failed: {0}")]
    Backend(String),
    #[error("agent event consumer is closed")]
    EventConsumerClosed,
}

/// Explicit non-agent used only for capability reporting on unsupported build
/// profiles. It returns errors and never falls back to a remote Agent gateway.
pub struct UnavailableAgentBackend {
    reason: String,
}

impl UnavailableAgentBackend {
    pub fn new(reason: impl Into<String>) -> Self {
        Self {
            reason: reason.into(),
        }
    }

    fn error(&self) -> AgentError {
        AgentError::Unavailable(self.reason.clone())
    }
}

#[async_trait]
impl AgentBackend for UnavailableAgentBackend {
    async fn start_thread(
        &self,
        _request: StartThreadRequest,
    ) -> Result<AgentThreadId, AgentError> {
        Err(self.error())
    }

    async fn send_message(
        &self,
        _request: AgentMessageRequest,
        _events: SharedAgentEventSink,
    ) -> Result<(), AgentError> {
        Err(self.error())
    }

    async fn interrupt(&self, _operation_id: &OperationId) -> Result<(), AgentError> {
        Err(self.error())
    }

    async fn resolve_approval(&self, _resolution: ApprovalResolution) -> Result<(), AgentError> {
        Err(self.error())
    }

    fn name(&self) -> &'static str {
        "unavailable"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn capability_matching_is_vendor_neutral() {
        let available = BackendCapabilities {
            tools: true,
            mcp: true,
            sandbox: true,
            headless: true,
            ..BackendCapabilities::default()
        };
        assert!(backend_supports(
            available,
            BackendCapabilities {
                tools: true,
                sandbox: true,
                ..BackendCapabilities::default()
            }
        ));
        assert!(!backend_supports(
            available,
            BackendCapabilities {
                subagents: true,
                ..BackendCapabilities::default()
            }
        ));
    }
}
