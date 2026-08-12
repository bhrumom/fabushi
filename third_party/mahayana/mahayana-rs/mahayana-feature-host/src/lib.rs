//! Product-level feature controller over the direct Mahayana Runtime Host.
//!
//! `HostMode::Test` is a deterministic in-process backend for fast E2E. It uses
//! real Rust commands, state, approvals, event ordering, and lifecycle without
//! network or simulator dependencies. Production provider mappings are added
//! feature-by-feature and must never silently fall back to test behavior.

#[cfg(feature = "production")]
use mahayana_core::ApprovalDecision as RuntimeApprovalDecision;
#[cfg(feature = "production")]
use mahayana_core::ApprovalId;
#[cfg(feature = "production")]
use mahayana_core::CODEX_ASSISTANT_CONVERSATION_ID;
#[cfg(feature = "production")]
use mahayana_core::ConversationId;
#[cfg(feature = "production")]
use mahayana_core::MessageRole as RuntimeMessageRole;
#[cfg(feature = "production")]
use mahayana_core::OperationId;
#[cfg(feature = "production")]
use mahayana_core::RuntimeCommand;
#[cfg(feature = "production")]
use mahayana_core::RuntimeEvent;
#[cfg(feature = "production")]
use mahayana_core::RuntimeResponse;
#[cfg(feature = "production")]
use mahayana_core::capability::MAHAYANA_AGENT_CAPABILITY_ID;
#[cfg(feature = "production")]
use mahayana_host::HostCreateConfig;
#[cfg(feature = "production")]
use mahayana_host::MahayanaHost;
#[cfg(feature = "production")]
use mahayana_host_protocol::ApprovalDecision;
use mahayana_host_protocol::ApprovalResolution;
use mahayana_host_protocol::CommandAccepted;
use mahayana_host_protocol::FeatureCommand;
use mahayana_host_protocol::HOST_PROTOCOL_VERSION;
use mahayana_host_protocol::HostConfig;
use mahayana_host_protocol::HostEvent;
use mahayana_host_protocol::HostInfo;
use mahayana_host_protocol::HostMode;
use mahayana_host_protocol::MessageRole;
use mahayana_host_protocol::SurfacePlatform;
#[cfg(feature = "production")]
use serde_json::json;
use std::collections::BTreeMap;
use std::collections::BTreeSet;
use std::collections::VecDeque;
use std::sync::Mutex;
use std::sync::MutexGuard;
#[cfg(feature = "production")]
use std::time::Duration;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

#[derive(Debug, thiserror::Error)]
pub enum FeatureHostError {
    #[cfg(feature = "production")]
    #[error(transparent)]
    Runtime(#[from] mahayana_host::HostError),
    #[error("production Runtime support is not compiled into this Host")]
    ProductionUnavailable,
    #[error("feature Host state mutex is poisoned")]
    StatePoisoned,
    #[error("feature Host is closed")]
    Closed,
    #[error("{0}")]
    Contract(String),
}

#[cfg_attr(not(feature = "production"), allow(dead_code))]
#[derive(Debug)]
struct PendingApproval {
    mini_app_id: String,
    capability: String,
    runtime_approval_id: Option<String>,
}

#[derive(Debug)]
struct FeatureState {
    events: VecDeque<HostEvent>,
    installed: BTreeMap<String, String>,
    pending_approvals: BTreeMap<String, PendingApproval>,
    operations: BTreeSet<String>,
    sequence: u64,
    closed: bool,
    session_active: bool,
}

impl Default for FeatureState {
    fn default() -> Self {
        Self {
            events: VecDeque::new(),
            installed: BTreeMap::new(),
            pending_approvals: BTreeMap::new(),
            operations: BTreeSet::new(),
            sequence: 0,
            closed: false,
            session_active: true,
        }
    }
}

pub struct FeatureHostController {
    config: HostConfig,
    info: HostInfo,
    #[cfg(feature = "production")]
    runtime: Option<MahayanaHost>,
    state: Mutex<FeatureState>,
}

impl FeatureHostController {
    pub fn create(config: HostConfig, platform: SurfacePlatform) -> Result<Self, FeatureHostError> {
        validate_config(&config)?;
        match config.mode {
            HostMode::Test => Ok(Self::create_test_backend(config, platform)),
            HostMode::Production => {
                #[cfg(feature = "production")]
                {
                    return Self::create_with_host_config(
                        config,
                        platform,
                        HostCreateConfig::default(),
                    );
                }
                #[cfg(not(feature = "production"))]
                {
                    Err(FeatureHostError::ProductionUnavailable)
                }
            }
        }
    }

    fn create_test_backend(config: HostConfig, platform: SurfacePlatform) -> Self {
        let info = HostInfo {
            runtime_version: "mahayana-test-backend".to_string(),
            protocol_version: HOST_PROTOCOL_VERSION.to_string(),
            platform,
        };
        let mut state = FeatureState::default();
        state.events.push_back(HostEvent::HostReady {
            timestamp: timestamp(),
            info: info.clone(),
        });
        Self {
            config,
            info,
            #[cfg(feature = "production")]
            runtime: None,
            state: Mutex::new(state),
        }
    }

    #[cfg(feature = "production")]
    pub fn create_with_host_config(
        config: HostConfig,
        platform: SurfacePlatform,
        host_config: HostCreateConfig,
    ) -> Result<Self, FeatureHostError> {
        validate_config(&config)?;
        if config.mode == HostMode::Test {
            return Ok(Self::create_test_backend(config, platform));
        }
        let runtime = MahayanaHost::create(host_config)?;
        let info = HostInfo {
            runtime_version: format!("mahayana-abi-{}", runtime.status().runtime_abi_version),
            protocol_version: HOST_PROTOCOL_VERSION.to_string(),
            platform,
        };
        let mut state = FeatureState::default();
        state.events.push_back(HostEvent::HostReady {
            timestamp: timestamp(),
            info: info.clone(),
        });
        Ok(Self {
            config,
            info,
            runtime: Some(runtime),
            state: Mutex::new(state),
        })
    }

    pub fn info(&self) -> HostInfo {
        self.info.clone()
    }

    pub fn execute(&self, command: FeatureCommand) -> Result<CommandAccepted, FeatureHostError> {
        match self.config.mode {
            HostMode::Test => self.execute_test(command),
            HostMode::Production => self.execute_production(command),
        }
    }

    pub fn receive(&self) -> Result<Option<HostEvent>, FeatureHostError> {
        if let Some(event) = self.state()?.events.pop_front() {
            return Ok(Some(event));
        }
        match self.config.mode {
            HostMode::Test => Ok(None),
            HostMode::Production => self.receive_production(),
        }
    }

    pub fn resolve_approval(&self, resolution: ApprovalResolution) -> Result<(), FeatureHostError> {
        let pending = {
            let mut state = self.state()?;
            ensure_open(&state)?;
            state
                .pending_approvals
                .remove(&resolution.approval_id)
                .ok_or_else(|| {
                    FeatureHostError::Contract(format!(
                        "unknown approval: {}",
                        resolution.approval_id
                    ))
                })?
        };

        #[cfg(not(feature = "production"))]
        let _ = &pending;

        if self.config.mode == HostMode::Production {
            #[cfg(feature = "production")]
            {
                if let Some(runtime_approval_id) = pending.runtime_approval_id {
                    let decision = match resolution.decision {
                        ApprovalDecision::AllowOnce => RuntimeApprovalDecision::Accept,
                        ApprovalDecision::Deny => RuntimeApprovalDecision::Decline,
                    };
                    self.runtime()?.resolve_approval(
                        ApprovalId(runtime_approval_id),
                        decision,
                        json!({
                            "miniAppId": pending.mini_app_id,
                            "capability": pending.capability,
                        }),
                    )?;
                }
            }
            #[cfg(not(feature = "production"))]
            {
                return Err(FeatureHostError::ProductionUnavailable);
            }
        }

        self.state()?.events.push_back(HostEvent::ApprovalResolved {
            timestamp: timestamp(),
            approval_id: resolution.approval_id,
            decision: resolution.decision,
        });
        Ok(())
    }

    pub fn interrupt(&self, operation_id: &str) -> Result<(), FeatureHostError> {
        {
            let state = self.state()?;
            ensure_open(&state)?;
            if !state.operations.contains(operation_id) {
                return Err(FeatureHostError::Contract(format!(
                    "unknown operation: {operation_id}"
                )));
            }
        }

        if self.config.mode == HostMode::Production {
            #[cfg(feature = "production")]
            self.runtime()?
                .interrupt(OperationId(operation_id.to_string()))?;
            #[cfg(not(feature = "production"))]
            return Err(FeatureHostError::ProductionUnavailable);
        }

        let mut state = self.state()?;
        state.operations.remove(operation_id);
        state.events.push_back(HostEvent::OperationInterrupted {
            timestamp: timestamp(),
            operation_id: operation_id.to_string(),
        });
        Ok(())
    }

    pub fn close(&self) -> Result<(), FeatureHostError> {
        let mut state = self.state()?;
        if state.closed {
            return Ok(());
        }
        state.closed = true;
        state.events.push_back(HostEvent::HostClosed {
            timestamp: timestamp(),
        });
        Ok(())
    }

    #[cfg(feature = "production")]
    fn runtime(&self) -> Result<&MahayanaHost, FeatureHostError> {
        self.runtime
            .as_ref()
            .ok_or(FeatureHostError::ProductionUnavailable)
    }

    #[cfg(not(feature = "production"))]
    fn execute_production(
        &self,
        _command: FeatureCommand,
    ) -> Result<CommandAccepted, FeatureHostError> {
        Err(FeatureHostError::ProductionUnavailable)
    }

    #[cfg(not(feature = "production"))]
    fn receive_production(&self) -> Result<Option<HostEvent>, FeatureHostError> {
        Err(FeatureHostError::ProductionUnavailable)
    }

    #[cfg(feature = "production")]
    fn translate_runtime_event(
        &self,
        event: RuntimeEvent,
    ) -> Result<Option<HostEvent>, FeatureHostError> {
        let event = match event {
            RuntimeEvent::Ready { .. } => None,
            RuntimeEvent::MessageDelta {
                operation_id,
                delta,
                ..
            } => Some(HostEvent::ChatDelta {
                timestamp: timestamp(),
                operation_id: operation_id.to_string(),
                delta,
            }),
            RuntimeEvent::MessageCompleted {
                operation_id,
                message,
                ..
            } => {
                let role = match message.role {
                    RuntimeMessageRole::User => MessageRole::User,
                    RuntimeMessageRole::Assistant
                    | RuntimeMessageRole::Contact
                    | RuntimeMessageRole::MiniApp
                    | RuntimeMessageRole::System => MessageRole::Assistant,
                };
                Some(HostEvent::ChatMessage {
                    timestamp: timestamp(),
                    role,
                    text: message.text,
                    operation_id: Some(operation_id.to_string()),
                })
            }
            RuntimeEvent::ApprovalRequested {
                approval_id,
                title,
                details,
                ..
            } => Some(self.translate_runtime_approval(approval_id, title, details)?),
            RuntimeEvent::OperationCompleted { operation_id } => {
                let operation_id = operation_id.to_string();
                self.state()?.operations.remove(&operation_id);
                Some(HostEvent::OperationCompleted {
                    timestamp: timestamp(),
                    operation_id,
                })
            }
            RuntimeEvent::OperationFailed {
                operation_id,
                code,
                message,
            } => {
                let operation_id = operation_id.to_string();
                self.state()?.operations.remove(&operation_id);
                Some(HostEvent::OperationFailed {
                    timestamp: timestamp(),
                    operation_id,
                    code,
                    message,
                })
            }
            RuntimeEvent::ModelUsageUpdated { .. }
            | RuntimeEvent::PluginProgress { .. }
            | RuntimeEvent::Lagged { .. }
            | RuntimeEvent::ProviderDegraded { .. } => None,
        };
        Ok(event)
    }

    #[cfg(feature = "production")]
    fn translate_runtime_approval(
        &self,
        approval_id: ApprovalId,
        title: String,
        details: serde_json::Value,
    ) -> Result<HostEvent, FeatureHostError> {
        let approval_key = approval_id.to_string();
        let mini_app_id = details
            .get("pluginId")
            .and_then(serde_json::Value::as_str)
            .unwrap_or("runtime")
            .to_string();
        let capability = details
            .get("capability")
            .and_then(serde_json::Value::as_str)
            .unwrap_or(title.as_str())
            .to_string();
        let reason = details
            .get("reason")
            .and_then(serde_json::Value::as_str)
            .map(str::to_string)
            .unwrap_or_else(|| details.to_string());
        self.state()?.pending_approvals.insert(
            approval_key.clone(),
            PendingApproval {
                mini_app_id: mini_app_id.clone(),
                capability: capability.clone(),
                runtime_approval_id: Some(approval_id.to_string()),
            },
        );
        Ok(HostEvent::ApprovalRequested {
            timestamp: timestamp(),
            approval_id: approval_key,
            mini_app_id,
            capability,
            reason,
        })
    }

    #[cfg(feature = "production")]
    fn receive_production(&self) -> Result<Option<HostEvent>, FeatureHostError> {
        for _ in 0..16 {
            let Some(event) = self.runtime()?.receive(Duration::from_millis(1))? else {
                return Ok(None);
            };
            if let Some(event) = self.translate_runtime_event(event)? {
                return Ok(Some(event));
            }
        }
        Ok(None)
    }

    #[cfg(feature = "production")]
    fn production_long_task(
        &self,
        request_id: String,
        label: String,
    ) -> Result<CommandAccepted, FeatureHostError> {
        let label = required(label, "operation label")?;
        let response = self.runtime()?.execute(RuntimeCommand::InvokeCapability {
            capability_id: MAHAYANA_AGENT_CAPABILITY_ID.to_string(),
            text: label.clone(),
            client_message_id: Some(request_id.clone()),
        })?;
        let operation_id = match response {
            RuntimeResponse::CapabilityAccepted { operation_id, .. } => operation_id.to_string(),
            other => return Err(unexpected_response("runtime.longTask", other)),
        };
        let mut state = self.state()?;
        state.operations.insert(operation_id.clone());
        state.events.push_back(HostEvent::OperationStarted {
            timestamp: timestamp(),
            operation_id: operation_id.clone(),
            label,
            interruptible: true,
        });
        Ok(CommandAccepted {
            request_id,
            operation_id: Some(operation_id),
        })
    }

    #[cfg(feature = "production")]
    fn production_clear_session(
        &self,
        request_id: String,
    ) -> Result<CommandAccepted, FeatureHostError> {
        self.runtime()?.clear_session()?;
        let mut state = self.state()?;
        state.session_active = false;
        state.events.push_back(HostEvent::SessionCleared {
            timestamp: timestamp(),
        });
        Ok(CommandAccepted {
            request_id,
            operation_id: None,
        })
    }

    #[cfg(feature = "production")]
    fn production_capability_request(
        &self,
        request_id: String,
        mini_app_id: String,
        capability: String,
        reason: String,
    ) -> Result<CommandAccepted, FeatureHostError> {
        let mini_app_id = required(mini_app_id, "miniAppId")?;
        let capability = required(capability, "capability")?;
        let reason = required(reason, "reason")?;
        let mut state = self.state()?;
        if !state.installed.contains_key(&mini_app_id) {
            return Err(FeatureHostError::Contract(format!(
                "MiniApp is not installed: {mini_app_id}"
            )));
        }
        let approval_id = next_id(&mut state, "approval");
        state.pending_approvals.insert(
            approval_id.clone(),
            PendingApproval {
                mini_app_id: mini_app_id.clone(),
                capability: capability.clone(),
                runtime_approval_id: None,
            },
        );
        state.events.push_back(HostEvent::ApprovalRequested {
            timestamp: timestamp(),
            approval_id,
            mini_app_id,
            capability,
            reason,
        });
        Ok(CommandAccepted {
            request_id,
            operation_id: None,
        })
    }

    #[cfg(feature = "production")]
    fn production_open(
        &self,
        request_id: String,
        mini_app_id: String,
    ) -> Result<CommandAccepted, FeatureHostError> {
        let mini_app_id = required(mini_app_id, "miniAppId")?;
        if !self.state()?.installed.contains_key(&mini_app_id) {
            return Err(FeatureHostError::Contract(format!(
                "MiniApp is not installed: {mini_app_id}"
            )));
        }
        match self.runtime()?.execute(RuntimeCommand::PluginUi {
            plugin_id: mini_app_id.clone(),
        })? {
            RuntimeResponse::PluginUi { .. } => {}
            other => return Err(unexpected_response("miniapp.open", other)),
        }
        self.state()?.events.push_back(HostEvent::MiniAppOpened {
            timestamp: timestamp(),
            mini_app_id,
        });
        Ok(CommandAccepted {
            request_id,
            operation_id: None,
        })
    }

    #[cfg(feature = "production")]
    fn production_install(
        &self,
        request_id: String,
        mini_app_id: String,
    ) -> Result<CommandAccepted, FeatureHostError> {
        let mini_app_id = required(mini_app_id, "miniAppId")?;
        let response = self.runtime()?.execute(RuntimeCommand::ListCapabilities {
            query: Some(format!("miniapp.{mini_app_id}")),
        })?;
        let available = match response {
            RuntimeResponse::Capabilities { data } => data.into_iter().any(|capability| {
                capability.plugin_id.as_deref() == Some(mini_app_id.as_str())
                    && capability.is_invokable()
            }),
            other => return Err(unexpected_response("marketplace.install", other)),
        };
        if !available {
            return Err(FeatureHostError::Contract(format!(
                "MiniApp is unavailable in the production Runtime: {mini_app_id}"
            )));
        }
        let version = "bundled".to_string();
        let mut state = self.state()?;
        state.installed.insert(mini_app_id.clone(), version.clone());
        state.events.push_back(HostEvent::MarketplaceInstalled {
            timestamp: timestamp(),
            mini_app_id,
            version,
        });
        Ok(CommandAccepted {
            request_id,
            operation_id: None,
        })
    }

    #[cfg(feature = "production")]
    fn production_chat(
        &self,
        request_id: String,
        text: String,
    ) -> Result<CommandAccepted, FeatureHostError> {
        let text = required(text, "chat text")?;
        let response = self.runtime()?.execute(RuntimeCommand::SendMessage {
            conversation_id: ConversationId(CODEX_ASSISTANT_CONVERSATION_ID.to_string()),
            text: text.clone(),
            client_message_id: Some(request_id.clone()),
        })?;
        let operation_id = match response {
            RuntimeResponse::Accepted { operation_id } => operation_id.to_string(),
            other => return Err(unexpected_response("chat.send", other)),
        };
        let mut state = self.state()?;
        state.operations.insert(operation_id.clone());
        state.events.push_back(HostEvent::ChatMessage {
            timestamp: timestamp(),
            role: MessageRole::User,
            text,
            operation_id: None,
        });
        state.events.push_back(HostEvent::OperationStarted {
            timestamp: timestamp(),
            operation_id: operation_id.clone(),
            label: "chat-response".into(),
            interruptible: true,
        });
        Ok(CommandAccepted {
            request_id,
            operation_id: Some(operation_id),
        })
    }

    #[cfg(feature = "production")]
    fn execute_production(
        &self,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, FeatureHostError> {
        let request_id = command.request_id().to_string();
        {
            let state = self.state()?;
            ensure_open(&state)?;
        }
        match command {
            FeatureCommand::ChatSend { text, .. } => self.production_chat(request_id, text),
            FeatureCommand::MarketplaceInstall { mini_app_id, .. } => {
                self.production_install(request_id, mini_app_id)
            }
            FeatureCommand::MiniAppOpen { mini_app_id, .. } => {
                self.production_open(request_id, mini_app_id)
            }
            FeatureCommand::CapabilityRequest {
                mini_app_id,
                capability,
                reason,
                ..
            } => self.production_capability_request(request_id, mini_app_id, capability, reason),
            FeatureCommand::RuntimeLongTask { label, .. } => {
                self.production_long_task(request_id, label)
            }
            FeatureCommand::SessionClear { .. } => self.production_clear_session(request_id),
        }
    }

    fn execute_test(&self, command: FeatureCommand) -> Result<CommandAccepted, FeatureHostError> {
        let request_id = command.request_id().to_string();
        let mut state = self.state()?;
        ensure_open(&state)?;
        match command {
            FeatureCommand::ChatSend { text, .. } => {
                let text = required(text, "chat text")?;
                let operation_id = next_id(&mut state, "chat");
                state.events.push_back(HostEvent::ChatMessage {
                    timestamp: timestamp(),
                    role: MessageRole::User,
                    text: text.clone(),
                    operation_id: None,
                });
                state.events.push_back(HostEvent::OperationStarted {
                    timestamp: timestamp(),
                    operation_id: operation_id.clone(),
                    label: "chat-response".into(),
                    interruptible: false,
                });
                state.events.push_back(HostEvent::ChatMessage {
                    timestamp: timestamp(),
                    role: MessageRole::Assistant,
                    text: format!("收到：{text}"),
                    operation_id: Some(operation_id.clone()),
                });
                Ok(CommandAccepted {
                    request_id,
                    operation_id: Some(operation_id),
                })
            }
            FeatureCommand::MarketplaceInstall { mini_app_id, .. } => {
                let mini_app_id = required(mini_app_id, "miniAppId")?;
                let version = "1.0.0".to_string();
                state.installed.insert(mini_app_id.clone(), version.clone());
                state.events.push_back(HostEvent::MarketplaceInstalled {
                    timestamp: timestamp(),
                    mini_app_id,
                    version,
                });
                Ok(CommandAccepted {
                    request_id,
                    operation_id: None,
                })
            }
            FeatureCommand::MiniAppOpen { mini_app_id, .. } => {
                let mini_app_id = required(mini_app_id, "miniAppId")?;
                if !state.installed.contains_key(&mini_app_id) {
                    return Err(FeatureHostError::Contract(format!(
                        "MiniApp is not installed: {mini_app_id}"
                    )));
                }
                state.events.push_back(HostEvent::MiniAppOpened {
                    timestamp: timestamp(),
                    mini_app_id,
                });
                Ok(CommandAccepted {
                    request_id,
                    operation_id: None,
                })
            }
            FeatureCommand::CapabilityRequest {
                mini_app_id,
                capability,
                reason,
                ..
            } => {
                let mini_app_id = required(mini_app_id, "miniAppId")?;
                let capability = required(capability, "capability")?;
                let reason = required(reason, "reason")?;
                let approval_id = next_id(&mut state, "approval");
                state.pending_approvals.insert(
                    approval_id.clone(),
                    PendingApproval {
                        mini_app_id: mini_app_id.clone(),
                        capability: capability.clone(),
                        runtime_approval_id: None,
                    },
                );
                state.events.push_back(HostEvent::ApprovalRequested {
                    timestamp: timestamp(),
                    approval_id,
                    mini_app_id,
                    capability,
                    reason,
                });
                Ok(CommandAccepted {
                    request_id,
                    operation_id: None,
                })
            }
            FeatureCommand::RuntimeLongTask { label, .. } => {
                let label = required(label, "operation label")?;
                let operation_id = next_id(&mut state, "operation");
                state.operations.insert(operation_id.clone());
                state.events.push_back(HostEvent::OperationStarted {
                    timestamp: timestamp(),
                    operation_id: operation_id.clone(),
                    label,
                    interruptible: true,
                });
                Ok(CommandAccepted {
                    request_id,
                    operation_id: Some(operation_id),
                })
            }
            FeatureCommand::SessionClear { .. } => {
                state.session_active = false;
                state.events.push_back(HostEvent::SessionCleared {
                    timestamp: timestamp(),
                });
                Ok(CommandAccepted {
                    request_id,
                    operation_id: None,
                })
            }
        }
    }

    fn state(&self) -> Result<MutexGuard<'_, FeatureState>, FeatureHostError> {
        self.state
            .lock()
            .map_err(|_| FeatureHostError::StatePoisoned)
    }
}

fn ensure_open(state: &FeatureState) -> Result<(), FeatureHostError> {
    if state.closed {
        Err(FeatureHostError::Closed)
    } else {
        Ok(())
    }
}

fn next_id(state: &mut FeatureState, prefix: &str) -> String {
    state.sequence += 1;
    format!("{prefix}-{}", state.sequence)
}

fn validate_config(config: &HostConfig) -> Result<(), FeatureHostError> {
    if config.profile_id.trim().is_empty() {
        Err(FeatureHostError::Contract(
            "profileId must not be empty".into(),
        ))
    } else {
        Ok(())
    }
}

#[cfg(feature = "production")]
fn unexpected_response(command: &str, response: RuntimeResponse) -> FeatureHostError {
    FeatureHostError::Contract(format!(
        "unexpected Runtime response for {command}: {response:?}"
    ))
}

fn required(value: String, name: &str) -> Result<String, FeatureHostError> {
    let value = value.trim();
    if value.is_empty() {
        Err(FeatureHostError::Contract(format!(
            "{name} must not be empty"
        )))
    } else {
        Ok(value.to_string())
    }
}

fn timestamp() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis().to_string())
        .unwrap_or_else(|_| "0".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use mahayana_host_protocol::ApprovalDecision;

    #[cfg(feature = "production")]
    fn isolated_host_config(profile: &str) -> HostCreateConfig {
        let root = std::env::temp_dir().join(format!(
            "fabushi-feature-host-{profile}-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).expect("create isolated Host root");
        HostCreateConfig {
            runtime: mahayana_core::RuntimeConfig {
                data_dir: Some(root.join("runtime")),
                ..Default::default()
            },
            product_session_path: Some(root.join("product-session.json")),
            inherit_installed_plugins: Some(false),
            ..Default::default()
        }
    }

    fn controller() -> FeatureHostController {
        FeatureHostController::create(
            HostConfig {
                profile_id: "fast-e2e".into(),
                mode: HostMode::Test,
            },
            SurfacePlatform::Tauri,
        )
        .expect("create feature Host")
    }

    fn drain(controller: &FeatureHostController) -> Vec<HostEvent> {
        let mut events = Vec::new();
        while let Some(event) = controller.receive().expect("receive event") {
            events.push(event);
        }
        events
    }

    #[test]
    fn deterministic_rust_backend_executes_every_declared_feature_journey() {
        let controller = controller();
        assert_eq!(drain(&controller)[0].kind(), "host.ready");

        controller
            .execute(FeatureCommand::ChatSend {
                request_id: "chat-1".into(),
                text: "验证极速自动化测试".into(),
            })
            .expect("chat");
        controller
            .execute(FeatureCommand::MarketplaceInstall {
                request_id: "install-1".into(),
                mini_app_id: "global-dharma".into(),
            })
            .expect("install");
        controller
            .execute(FeatureCommand::MiniAppOpen {
                request_id: "open-1".into(),
                mini_app_id: "global-dharma".into(),
            })
            .expect("open");
        controller
            .execute(FeatureCommand::CapabilityRequest {
                request_id: "capability-1".into(),
                mini_app_id: "global-dharma".into(),
                capability: "camera".into(),
                reason: "scan scripture".into(),
            })
            .expect("capability");
        let approval_id = drain(&controller)
            .into_iter()
            .find_map(|event| match event {
                HostEvent::ApprovalRequested { approval_id, .. } => Some(approval_id),
                _ => None,
            })
            .expect("approval id");
        controller
            .resolve_approval(ApprovalResolution {
                approval_id,
                decision: ApprovalDecision::AllowOnce,
            })
            .expect("resolve approval");
        let operation = controller
            .execute(FeatureCommand::RuntimeLongTask {
                request_id: "operation-1".into(),
                label: "index scriptures".into(),
            })
            .expect("long task")
            .operation_id
            .expect("operation id");
        controller.interrupt(&operation).expect("interrupt");
        controller
            .execute(FeatureCommand::SessionClear {
                request_id: "session-1".into(),
            })
            .expect("clear session");
        controller.close().expect("close");

        let kinds = drain(&controller)
            .into_iter()
            .map(|event| event.kind())
            .collect::<Vec<_>>();
        assert!(kinds.contains(&"approval.resolved"));
        assert!(kinds.contains(&"operation.started"));
        assert!(kinds.contains(&"operation.interrupted"));
        assert!(kinds.contains(&"session.cleared"));
        assert!(kinds.contains(&"host.closed"));
    }

    #[cfg(not(feature = "production"))]
    #[test]
    fn production_mode_requires_the_explicit_runtime_feature() {
        let error = FeatureHostController::create(
            HostConfig {
                profile_id: "production".into(),
                mode: HostMode::Production,
            },
            SurfacePlatform::Tauri,
        )
        .err()
        .expect("production must not fall back to the test backend");
        assert!(matches!(error, FeatureHostError::ProductionUnavailable));
    }

    #[cfg(feature = "production")]
    #[test]
    fn production_uses_the_real_runtime_and_rust_owned_session_store() {
        let controller = FeatureHostController::create_with_host_config(
            HostConfig {
                profile_id: "production".into(),
                mode: HostMode::Production,
            },
            SurfacePlatform::Tauri,
            isolated_host_config("production"),
        )
        .expect("create feature Host");
        let ready = drain(&controller);
        assert_eq!(ready[0].kind(), "host.ready");
        assert!(
            controller
                .info()
                .runtime_version
                .starts_with("mahayana-abi-")
        );

        controller
            .execute(FeatureCommand::MarketplaceInstall {
                request_id: "install-1".into(),
                mini_app_id: "global-dharma".into(),
            })
            .expect("verify bundled production MiniApp");
        controller
            .execute(FeatureCommand::SessionClear {
                request_id: "session-1".into(),
            })
            .expect("clear isolated Rust session");

        let kinds = drain(&controller)
            .into_iter()
            .map(|event| event.kind())
            .collect::<Vec<_>>();
        assert!(kinds.contains(&"marketplace.installed"));
        assert!(kinds.contains(&"session.cleared"));
    }

    #[cfg(feature = "production")]
    #[test]
    fn production_runtime_events_preserve_streaming_and_terminal_states() {
        let controller = FeatureHostController::create_with_host_config(
            HostConfig {
                profile_id: "production-events".into(),
                mode: HostMode::Production,
            },
            SurfacePlatform::Tauri,
            isolated_host_config("production-events"),
        )
        .expect("create production event Host");
        let operation_id = OperationId("operation-1".into());
        let conversation_id = ConversationId(CODEX_ASSISTANT_CONVERSATION_ID.into());

        let delta = controller
            .translate_runtime_event(RuntimeEvent::MessageDelta {
                operation_id: operation_id.clone(),
                conversation_id: conversation_id.clone(),
                delta: "般若".into(),
            })
            .expect("translate delta")
            .expect("delta event");
        assert!(matches!(
            delta,
            HostEvent::ChatDelta {
                operation_id: ref current,
                ref delta,
                ..
            } if current == "operation-1" && delta == "般若"
        ));

        let completed = controller
            .translate_runtime_event(RuntimeEvent::MessageCompleted {
                operation_id: operation_id.clone(),
                message: mahayana_core::Message {
                    id: mahayana_core::MessageId("message-1".into()),
                    conversation_id,
                    role: RuntimeMessageRole::Assistant,
                    text: "般若波罗蜜多".into(),
                    created_at_ms: 1,
                    metadata: serde_json::json!({}),
                },
            })
            .expect("translate completed message")
            .expect("completed message event");
        assert!(matches!(
            completed,
            HostEvent::ChatMessage {
                operation_id: Some(ref current),
                role: MessageRole::Assistant,
                ref text,
                ..
            } if current == "operation-1" && text == "般若波罗蜜多"
        ));

        let terminal = controller
            .translate_runtime_event(RuntimeEvent::OperationCompleted {
                operation_id: operation_id.clone(),
            })
            .expect("translate completion")
            .expect("completion event");
        assert!(matches!(
            terminal,
            HostEvent::OperationCompleted {
                operation_id: ref current,
                ..
            } if current == "operation-1"
        ));

        let failed = controller
            .translate_runtime_event(RuntimeEvent::OperationFailed {
                operation_id,
                code: "provider_error".into(),
                message: "provider unavailable".into(),
            })
            .expect("translate failure")
            .expect("failure event");
        assert!(matches!(
            failed,
            HostEvent::OperationFailed {
                operation_id: ref current,
                ref code,
                ref message,
                ..
            } if current == "operation-1"
                && code == "provider_error"
                && message == "provider unavailable"
        ));
    }
}
