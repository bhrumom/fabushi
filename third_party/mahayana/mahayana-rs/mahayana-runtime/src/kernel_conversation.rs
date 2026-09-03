use async_trait::async_trait;
use mahayana_conversation::{
    ConversationError, ConversationProvider, MAHAYANA_AI_PROVIDER_KEY, ResolveApprovalRequest,
    SendMessageRequest, SharedConversationEventSink,
};
use mahayana_core::{
    ApprovalDecision, ApprovalId, BuildProfile, Conversation, ConversationId, Message, MessageId,
    MessageRole, ModelTokenUsage, ModelTokenUsageSnapshot, OperationId, RuntimeActivityStatus,
    RuntimeEvent,
};
use mahayana_kernel::{
    ApprovalResolution, Capability, CapabilitySet, EngineBackend, ExecutionPolicy, KernelError,
    KernelEvent, KernelEventSink, OpenSessionRequest, OperationId as KernelOperationId, RiskLevel,
    RunRequest, RuntimeProfile, SessionId, SharedKernelEventSink,
};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::Mutex as AsyncMutex;

use super::{load_conversation_history, persist_conversation_history};

pub const MAHAYANA_AI_CONVERSATION_ID: &str = "mahayana-ai:agent:assistant";

pub struct KernelConversationProvider {
    backend: Arc<dyn EngineBackend>,
    profile: BuildProfile,
    workspace_root: Option<String>,
    model: Option<String>,
    history_path: Mutex<Option<PathBuf>>,
    session_ids: AsyncMutex<HashMap<String, SessionId>>,
    history: Arc<Mutex<Vec<Message>>>,
}

impl KernelConversationProvider {
    pub fn new(
        backend: Arc<dyn EngineBackend>,
        profile: BuildProfile,
        workspace_root: Option<String>,
        model: Option<String>,
        history_path: Option<PathBuf>,
    ) -> Self {
        Self {
            backend,
            profile,
            workspace_root,
            model,
            history: Arc::new(Mutex::new(load_conversation_history(
                history_path.as_deref(),
            ))),
            history_path: Mutex::new(history_path),
            session_ids: AsyncMutex::new(HashMap::new()),
        }
    }

    fn history_path_snapshot(&self) -> Result<Option<PathBuf>, ConversationError> {
        self.history_path
            .lock()
            .map(|path| path.clone())
            .map_err(|_| ConversationError::Provider("kernel history path mutex poisoned".into()))
    }

    async fn session_id(
        &self,
        conversation_id: &ConversationId,
    ) -> Result<SessionId, ConversationError> {
        let key = conversation_id.as_str().to_string();
        let mut session_ids = self.session_ids.lock().await;
        if let Some(session_id) = session_ids.get(&key) {
            return Ok(session_id.clone());
        }
        let history = self
            .history
            .lock()
            .map_err(|_| ConversationError::Provider("kernel history mutex poisoned".into()))?
            .iter()
            .filter(|message| &message.conversation_id == conversation_id)
            .map(|message| {
                json!({
                    "role": match message.role {
                        MessageRole::User => "user",
                        MessageRole::Assistant => "assistant",
                        MessageRole::Contact => "user",
                        MessageRole::MiniApp => "assistant",
                        MessageRole::System => "system",
                    },
                    "content": message.text,
                })
            })
            .collect::<Vec<_>>();
        let created = self
            .backend
            .open_session(OpenSessionRequest {
                profile: runtime_profile(self.profile),
                workspace_root: self.workspace_root.clone(),
                model: self.model.clone(),
                metadata: json!({
                    "conversationId": conversation_id.as_str(),
                    "history": history,
                }),
            })
            .await
            .map_err(kernel_error)?;
        session_ids.insert(key, created.clone());
        Ok(created)
    }
}

#[async_trait]
impl ConversationProvider for KernelConversationProvider {
    fn key(&self) -> &'static str {
        MAHAYANA_AI_PROVIDER_KEY
    }

    async fn list_conversations(&self) -> Result<Vec<Conversation>, ConversationError> {
        Ok(vec![Conversation::mahayana_assistant()])
    }

    async fn history(
        &self,
        conversation_id: &ConversationId,
        limit: u32,
    ) -> Result<Vec<Message>, ConversationError> {
        let history = self
            .history
            .lock()
            .map_err(|_| ConversationError::Provider("kernel history mutex poisoned".into()))?;
        let matching = history
            .iter()
            .filter(|message| &message.conversation_id == conversation_id)
            .cloned()
            .collect::<Vec<_>>();
        let start = matching.len().saturating_sub(limit as usize);
        Ok(matching[start..].to_vec())
    }

    async fn send_message(
        &self,
        request: SendMessageRequest,
        events: SharedConversationEventSink,
    ) -> Result<(), ConversationError> {
        let session_id = self.session_id(&request.conversation_id).await?;
        let history_path = self.history_path_snapshot()?;
        let user_message = Message {
            id: request
                .client_message_id
                .as_deref()
                .and_then(|id| MessageId::new(id).ok())
                .unwrap_or_else(|| MessageId::generated("message")),
            conversation_id: request.conversation_id.clone(),
            role: MessageRole::User,
            text: request.text.clone(),
            created_at_ms: now_ms(),
            metadata: json!({"runtime": "mahayana-kernel"}),
        };
        if !request.hidden {
            let mut history = self
                .history
                .lock()
                .map_err(|_| ConversationError::Provider("kernel history mutex poisoned".into()))?;
            history.push(user_message);
            persist_conversation_history(history_path.as_deref(), &history)
                .map_err(ConversationError::Provider)?;
        }

        let kernel_operation_id = KernelOperationId::from_string(request.operation_id.as_str());
        let sink: SharedKernelEventSink = Arc::new(RuntimeKernelEventBridge {
            conversation_id: request.conversation_id,
            operation_id: request.operation_id,
            events,
            history: Arc::clone(&self.history),
            history_path,
            tool_steps: Mutex::new(HashMap::new()),
            tool_sequence: Mutex::new(0),
        });
        self.backend
            .run(
                RunRequest {
                    session_id,
                    operation_id: kernel_operation_id,
                    input: request.text,
                    policy: execution_policy(self.profile),
                    required_capabilities: CapabilitySet::new([Capability::Model]),
                    metadata: json!({"clientMessageId": request.client_message_id}),
                },
                sink,
            )
            .await
            .map_err(kernel_error)
    }

    async fn interrupt(&self, operation_id: &OperationId) -> Result<(), ConversationError> {
        self.backend
            .interrupt(&KernelOperationId::from_string(operation_id.as_str()))
            .await
            .map_err(kernel_error)
    }

    async fn resolve_approval(
        &self,
        request: ResolveApprovalRequest,
    ) -> Result<(), ConversationError> {
        self.backend
            .resolve_approval(ApprovalResolution {
                approval_id: request.approval_id.to_string(),
                approved: matches!(
                    request.decision,
                    ApprovalDecision::Accept | ApprovalDecision::AcceptForSession
                ),
                metadata: request.payload,
            })
            .await
            .map_err(kernel_error)
    }

    async fn reset_session(&self) -> Result<(), ConversationError> {
        self.backend.reset_session().map_err(kernel_error)?;
        self.session_ids.lock().await.clear();
        let mut history = self
            .history
            .lock()
            .map_err(|_| ConversationError::Provider("kernel history mutex poisoned".into()))?;
        history.clear();
        Ok(())
    }

    async fn set_history_path(&self, path: Option<PathBuf>) -> Result<(), ConversationError> {
        self.backend.reset_session().map_err(kernel_error)?;
        self.session_ids.lock().await.clear();
        let loaded = load_conversation_history(path.as_deref());
        *self
            .history
            .lock()
            .map_err(|_| ConversationError::Provider("kernel history mutex poisoned".into()))? =
            loaded;
        *self.history_path.lock().map_err(|_| {
            ConversationError::Provider("kernel history path mutex poisoned".into())
        })? = path;
        Ok(())
    }
}

struct RuntimeKernelEventBridge {
    conversation_id: ConversationId,
    operation_id: OperationId,
    events: SharedConversationEventSink,
    history: Arc<Mutex<Vec<Message>>>,
    history_path: Option<PathBuf>,
    tool_steps: Mutex<HashMap<String, Vec<String>>>,
    tool_sequence: Mutex<u64>,
}

impl RuntimeKernelEventBridge {
    fn emit_runtime(&self, event: RuntimeEvent) -> Result<(), KernelError> {
        self.events
            .emit(event)
            .map_err(|error| KernelError::Backend(error.to_string()))
    }

    fn activity(
        &self,
        step_id: String,
        kind: String,
        title: String,
        detail: Option<String>,
        status: RuntimeActivityStatus,
        metadata: Option<Value>,
    ) -> Result<(), KernelError> {
        self.emit_runtime(RuntimeEvent::AgentActivity {
            operation_id: self.operation_id.clone(),
            step_id,
            kind,
            title,
            detail,
            status,
            metadata,
        })
    }

    fn start_tool_step(&self, tool: &str) -> Result<String, KernelError> {
        let sequence = {
            let mut sequence = self
                .tool_sequence
                .lock()
                .map_err(|_| KernelError::Backend("tool sequence mutex poisoned".into()))?;
            *sequence = sequence.saturating_add(1);
            *sequence
        };
        let step_id = format!("tool:{tool}:{sequence}");
        self.tool_steps
            .lock()
            .map_err(|_| KernelError::Backend("tool step mutex poisoned".into()))?
            .entry(tool.to_string())
            .or_default()
            .push(step_id.clone());
        Ok(step_id)
    }

    fn finish_tool_step(&self, tool: &str) -> Result<String, KernelError> {
        Ok(self
            .tool_steps
            .lock()
            .map_err(|_| KernelError::Backend("tool step mutex poisoned".into()))?
            .get_mut(tool)
            .and_then(|steps| steps.pop())
            .unwrap_or_else(|| format!("tool:{tool}:completed")))
    }
}

impl KernelEventSink for RuntimeKernelEventBridge {
    fn emit(&self, event: KernelEvent) -> Result<(), KernelError> {
        match event {
            KernelEvent::MessageDelta { delta, .. } => {
                self.emit_runtime(RuntimeEvent::MessageDelta {
                    operation_id: self.operation_id.clone(),
                    conversation_id: self.conversation_id.clone(),
                    delta,
                })
            }
            KernelEvent::MessageCompleted { text, .. } => {
                let message = Message {
                    id: MessageId::generated("message"),
                    conversation_id: self.conversation_id.clone(),
                    role: MessageRole::Assistant,
                    text,
                    created_at_ms: now_ms(),
                    metadata: json!({"runtime": "mahayana-kernel"}),
                };
                let mut history = self
                    .history
                    .lock()
                    .map_err(|_| KernelError::Backend("kernel history mutex poisoned".into()))?;
                history.push(message.clone());
                persist_conversation_history(self.history_path.as_deref(), &history)
                    .map_err(KernelError::Backend)?;
                self.emit_runtime(RuntimeEvent::MessageCompleted {
                    operation_id: self.operation_id.clone(),
                    message,
                })
            }
            KernelEvent::UsageUpdated {
                input_tokens,
                output_tokens,
                ..
            } => {
                let total_tokens = input_tokens.saturating_add(output_tokens);
                self.emit_runtime(RuntimeEvent::ModelUsageUpdated {
                    operation_id: self.operation_id.clone(),
                    usage: ModelTokenUsageSnapshot {
                        total: None,
                        last: ModelTokenUsage {
                            total_tokens: i64::try_from(total_tokens).unwrap_or(i64::MAX),
                            input_tokens: i64::try_from(input_tokens).unwrap_or(i64::MAX),
                            cached_input_tokens: 0,
                            output_tokens: i64::try_from(output_tokens).unwrap_or(i64::MAX),
                            reasoning_output_tokens: 0,
                        },
                        model_context_window: None,
                    },
                })
            }
            KernelEvent::Activity {
                kind,
                title,
                detail,
                metadata,
                ..
            } => {
                let step_id = metadata
                    .get("stepId")
                    .and_then(Value::as_str)
                    .map(str::to_owned)
                    .unwrap_or_else(|| format!("kernel-step:{}", self.operation_id));
                let status = metadata
                    .get("status")
                    .and_then(Value::as_str)
                    .map(runtime_activity_status)
                    .unwrap_or(RuntimeActivityStatus::Running);
                self.activity(step_id, kind, title, detail, status, Some(metadata))
            }
            KernelEvent::ToolStarted { tool, .. } if tool == "send_message" => Ok(()),
            KernelEvent::ToolStarted {
                tool, arguments, ..
            } => {
                let step_id = self.start_tool_step(&tool)?;
                self.activity(
                    step_id,
                    "tool".into(),
                    format!("调用工具 · {tool}"),
                    None,
                    RuntimeActivityStatus::Running,
                    Some(json!({"tool": tool, "arguments": arguments})),
                )
            }
            KernelEvent::ToolCompleted { tool, .. } if tool == "send_message" => Ok(()),
            KernelEvent::ToolCompleted {
                tool,
                output,
                success,
                ..
            } => {
                let step_id = self.finish_tool_step(&tool)?;
                self.activity(
                    step_id,
                    "tool".into(),
                    format!("工具完成 · {tool}"),
                    Some(if success {
                        "执行成功".into()
                    } else {
                        "执行失败".into()
                    }),
                    if success {
                        RuntimeActivityStatus::Completed
                    } else {
                        RuntimeActivityStatus::Failed
                    },
                    Some(json!({"tool": tool, "output": output, "success": success})),
                )
            }
            KernelEvent::ApprovalRequested {
                approval_id,
                title,
                risk,
                details,
                ..
            } => {
                let approval_id = ApprovalId::new(approval_id)
                    .map_err(|error| KernelError::Backend(error.to_string()))?;
                self.emit_runtime(RuntimeEvent::ApprovalRequested {
                    operation_id: self.operation_id.clone(),
                    approval_id,
                    title,
                    details: json!({"risk": risk, "details": details}),
                })
            }
            KernelEvent::CheckpointCreated {
                checkpoint_id,
                label,
                ..
            } => self.activity(
                format!("checkpoint:{checkpoint_id}"),
                "checkpoint".into(),
                label.unwrap_or_else(|| "Workspace checkpoint".into()),
                Some(checkpoint_id.clone()),
                RuntimeActivityStatus::Completed,
                Some(json!({"checkpointId": checkpoint_id})),
            ),
            KernelEvent::OperationCompleted { .. } => Ok(()),
            KernelEvent::OperationFailed {
                message, retryable, ..
            } => self.activity(
                format!("operation:{}", self.operation_id),
                "operation".into(),
                "Operation failed".into(),
                Some(message),
                RuntimeActivityStatus::Failed,
                Some(json!({"retryable": retryable})),
            ),
        }
    }
}

fn runtime_profile(profile: BuildProfile) -> RuntimeProfile {
    match profile {
        BuildProfile::DesktopFull => RuntimeProfile::DesktopFull,
        BuildProfile::MobileEmbedded => RuntimeProfile::MobileEmbedded,
        BuildProfile::WebWasm => RuntimeProfile::WebWasm,
    }
}

fn execution_policy(profile: BuildProfile) -> ExecutionPolicy {
    match profile {
        BuildProfile::DesktopFull => ExecutionPolicy::interactive_default(),
        BuildProfile::MobileEmbedded | BuildProfile::WebWasm => ExecutionPolicy::mobile_default(),
    }
}

fn runtime_activity_status(value: &str) -> RuntimeActivityStatus {
    match value {
        "completed" => RuntimeActivityStatus::Completed,
        "failed" => RuntimeActivityStatus::Failed,
        _ => RuntimeActivityStatus::Running,
    }
}

fn kernel_error(error: KernelError) -> ConversationError {
    match error {
        KernelError::OperationNotFound(id) => ConversationError::OperationNotFound(
            OperationId::new(id).unwrap_or_else(|_| OperationId::generated("operation")),
        ),
        KernelError::ApprovalNotFound(id) => ConversationError::ApprovalNotFound(
            ApprovalId::new(id).unwrap_or_else(|_| ApprovalId::generated("approval")),
        ),
        other => ConversationError::Provider(other.to_string()),
    }
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
        .try_into()
        .unwrap_or(i64::MAX)
}
