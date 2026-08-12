//! Product-level feature controller over the direct Mahayana Runtime Host.
//!
//! `HostMode::Test` is a deterministic in-process backend for fast E2E. It uses
//! real Rust commands, state, approvals, event ordering, and lifecycle without
//! network or simulator dependencies. Production provider mappings are added
//! feature-by-feature and must never silently fall back to test behavior.

use mahayana_host::HostCreateConfig;
use mahayana_host::MahayanaHost;
use mahayana_host_protocol::ApprovalDecision;
use mahayana_host_protocol::ApprovalResolution;
use mahayana_host_protocol::CommandAccepted;
use mahayana_host_protocol::FeatureCommand;
use mahayana_host_protocol::HostConfig;
use mahayana_host_protocol::HostEvent;
use mahayana_host_protocol::HostInfo;
use mahayana_host_protocol::HostMode;
use mahayana_host_protocol::MessageRole;
use mahayana_host_protocol::SurfacePlatform;
use mahayana_host_protocol::HOST_PROTOCOL_VERSION;
use std::collections::BTreeMap;
use std::collections::BTreeSet;
use std::collections::VecDeque;
use std::sync::Mutex;
use std::sync::MutexGuard;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

#[derive(Debug, thiserror::Error)]
pub enum FeatureHostError {
    #[error(transparent)]
    Runtime(#[from] mahayana_host::HostError),
    #[error("feature Host state mutex is poisoned")]
    StatePoisoned,
    #[error("feature Host is closed")]
    Closed,
    #[error("{0}")]
    Contract(String),
    #[error("production adapter is not implemented for `{0}`")]
    ProductionAdapterMissing(&'static str),
}

#[derive(Debug)]
struct PendingApproval {
    mini_app_id: String,
    capability: String,
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
    _runtime: MahayanaHost,
    state: Mutex<FeatureState>,
}

impl FeatureHostController {
    pub fn create(
        config: HostConfig,
        platform: SurfacePlatform,
    ) -> Result<Self, FeatureHostError> {
        if config.profile_id.trim().is_empty() {
            return Err(FeatureHostError::Contract(
                "profileId must not be empty".into(),
            ));
        }
        let runtime = MahayanaHost::create(HostCreateConfig::default())?;
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
            _runtime: runtime,
            state: Mutex::new(state),
        })
    }

    pub fn info(&self) -> HostInfo {
        self.info.clone()
    }

    pub fn execute(
        &self,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, FeatureHostError> {
        if self.config.mode == HostMode::Production {
            return Err(FeatureHostError::ProductionAdapterMissing(command_kind(
                &command,
            )));
        }
        self.execute_test(command)
    }

    pub fn receive(&self) -> Result<Option<HostEvent>, FeatureHostError> {
        Ok(self.state()?.events.pop_front())
    }

    pub fn resolve_approval(
        &self,
        resolution: ApprovalResolution,
    ) -> Result<(), FeatureHostError> {
        if self.config.mode == HostMode::Production {
            return Err(FeatureHostError::ProductionAdapterMissing(
                "approval.resolve",
            ));
        }
        let mut state = self.state()?;
        ensure_open(&state)?;
        let pending = state
            .pending_approvals
            .remove(&resolution.approval_id)
            .ok_or_else(|| {
                FeatureHostError::Contract(format!(
                    "unknown approval: {}",
                    resolution.approval_id
                ))
            })?;
        let _audit_identity = (pending.mini_app_id, pending.capability);
        state.events.push_back(HostEvent::ApprovalResolved {
            timestamp: timestamp(),
            approval_id: resolution.approval_id,
            decision: resolution.decision,
        });
        Ok(())
    }

    pub fn interrupt(&self, operation_id: &str) -> Result<(), FeatureHostError> {
        if self.config.mode == HostMode::Production {
            return Err(FeatureHostError::ProductionAdapterMissing(
                "operation.interrupt",
            ));
        }
        let mut state = self.state()?;
        ensure_open(&state)?;
        if !state.operations.remove(operation_id) {
            return Err(FeatureHostError::Contract(format!(
                "unknown operation: {operation_id}"
            )));
        }
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

    fn execute_test(
        &self,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, FeatureHostError> {
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

fn command_kind(command: &FeatureCommand) -> &'static str {
    match command {
        FeatureCommand::ChatSend { .. } => "chat.send",
        FeatureCommand::MarketplaceInstall { .. } => "marketplace.install",
        FeatureCommand::MiniAppOpen { .. } => "miniapp.open",
        FeatureCommand::CapabilityRequest { .. } => "capability.request",
        FeatureCommand::RuntimeLongTask { .. } => "runtime.longTask",
        FeatureCommand::SessionClear { .. } => "session.clear",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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

    #[test]
    fn production_never_silently_falls_back_to_the_test_backend() {
        let controller = FeatureHostController::create(
            HostConfig {
                profile_id: "production".into(),
                mode: HostMode::Production,
            },
            SurfacePlatform::Tauri,
        )
        .expect("create feature Host");
        let error = controller
            .execute(FeatureCommand::SessionClear {
                request_id: "session-1".into(),
            })
            .expect_err("missing production adapter must fail");
        assert!(error.to_string().contains("production adapter"));
    }
}
