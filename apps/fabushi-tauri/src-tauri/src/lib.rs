//! Thin Tauri shell around the direct `mahayana-host` Rust API.
//!
//! Both state machines are independent from Tauri so ordinary pull requests
//! exercise raw Runtime commands and complete product-level user journeys
//! without a window server or simulator.

use mahayana_core::RuntimeCommand;
use mahayana_feature_host::FeatureHostController;
use mahayana_host::HostCreateConfig;
use mahayana_host::MahayanaHost;
use mahayana_host_protocol::ApprovalResolution;
use mahayana_host_protocol::CommandAccepted;
use mahayana_host_protocol::FeatureCommand;
use mahayana_host_protocol::HostConfig as FeatureHostConfig;
use mahayana_host_protocol::HostEvent;
use mahayana_host_protocol::HostInfo;
use mahayana_host_protocol::SurfacePlatform;
use serde_json::Value;
use serde_json::json;
use std::sync::Mutex;
use std::time::Duration;

#[derive(Default)]
pub struct HostState {
    host: Mutex<Option<MahayanaHost>>,
}

impl HostState {
    pub fn initialize(&self, config: Option<Value>) -> Result<Value, String> {
        let config = config
            .map(serde_json::from_value::<HostCreateConfig>)
            .transpose()
            .map_err(|error| format!("invalid Host configuration: {error}"))?
            .unwrap_or_default();
        let host = MahayanaHost::create(config).map_err(|error| error.to_string())?;
        let status = serde_json::to_value(host.status()).map_err(|error| error.to_string())?;
        *self.lock()? = Some(host);
        Ok(json!({"initialized": true, "status": status}))
    }

    pub fn execute(&self, command: Value) -> Result<Value, String> {
        let command: RuntimeCommand = serde_json::from_value(command)
            .map_err(|error| format!("invalid Runtime command: {error}"))?;
        let response = self.with_host(|host| host.execute(command))?;
        serde_json::to_value(response).map_err(|error| error.to_string())
    }

    pub fn receive(&self, timeout_ms: u64) -> Result<Value, String> {
        let event = self.with_host(|host| host.receive(Duration::from_millis(timeout_ms)))?;
        serde_json::to_value(event).map_err(|error| error.to_string())
    }

    pub fn close(&self) -> Result<Value, String> {
        let removed = self.lock()?.take().is_some();
        Ok(json!({"closed": removed}))
    }

    pub fn snapshot(&self) -> Result<Value, String> {
        let guard = self.lock()?;
        Ok(match guard.as_ref() {
            Some(host) => json!({
                "initialized": true,
                "status": host.status(),
            }),
            None => json!({"initialized": false}),
        })
    }

    fn with_host<T>(
        &self,
        operation: impl FnOnce(&MahayanaHost) -> Result<T, mahayana_host::HostError>,
    ) -> Result<T, String> {
        let guard = self.lock()?;
        let host = guard
            .as_ref()
            .ok_or_else(|| "Mahayana Host is not initialized".to_string())?;
        operation(host).map_err(|error| error.to_string())
    }

    fn lock(&self) -> Result<std::sync::MutexGuard<'_, Option<MahayanaHost>>, String> {
        self.host
            .lock()
            .map_err(|_| "Mahayana Host state mutex is poisoned".to_string())
    }
}

#[derive(Default)]
pub struct FeatureHostState {
    controller: Mutex<Option<FeatureHostController>>,
}

impl FeatureHostState {
    pub fn initialize(&self, config: FeatureHostConfig) -> Result<HostInfo, String> {
        let controller = FeatureHostController::create(config, SurfacePlatform::Tauri)
            .map_err(|error| error.to_string())?;
        let info = controller.info();
        *self.lock()? = Some(controller);
        Ok(info)
    }

    pub fn execute(&self, command: FeatureCommand) -> Result<CommandAccepted, String> {
        self.with_controller(|controller| controller.execute(command))
    }

    pub fn receive(&self) -> Result<Option<HostEvent>, String> {
        self.with_controller(|controller| controller.receive())
    }

    pub fn resolve_approval(&self, resolution: ApprovalResolution) -> Result<(), String> {
        self.with_controller(|controller| controller.resolve_approval(resolution))
    }

    pub fn interrupt(&self, operation_id: &str) -> Result<(), String> {
        self.with_controller(|controller| controller.interrupt(operation_id))
    }

    pub fn close(&self) -> Result<(), String> {
        let mut guard = self.lock()?;
        if let Some(controller) = guard.as_ref() {
            controller.close().map_err(|error| error.to_string())?;
        }
        *guard = None;
        Ok(())
    }

    fn with_controller<T>(
        &self,
        operation: impl FnOnce(
            &FeatureHostController,
        ) -> Result<T, mahayana_feature_host::FeatureHostError>,
    ) -> Result<T, String> {
        let guard = self.lock()?;
        let controller = guard
            .as_ref()
            .ok_or_else(|| "Mahayana feature Host is not initialized".to_string())?;
        operation(controller).map_err(|error| error.to_string())
    }

    fn lock(
        &self,
    ) -> Result<std::sync::MutexGuard<'_, Option<FeatureHostController>>, String> {
        self.controller
            .lock()
            .map_err(|_| "Mahayana feature Host state mutex is poisoned".to_string())
    }
}

#[cfg(feature = "desktop")]
mod desktop {
    use super::FeatureHostState;
    use super::HostState;
    use mahayana_host_protocol::ApprovalResolution;
    use mahayana_host_protocol::CommandAccepted;
    use mahayana_host_protocol::FeatureCommand;
    use mahayana_host_protocol::HostConfig;
    use mahayana_host_protocol::HostEvent;
    use mahayana_host_protocol::HostInfo;
    use serde_json::Value;
    use tauri::State;

    #[tauri::command]
    fn host_initialize(
        state: State<'_, HostState>,
        config: Option<Value>,
    ) -> Result<Value, String> {
        state.initialize(config)
    }

    #[tauri::command]
    fn host_execute(state: State<'_, HostState>, command: Value) -> Result<Value, String> {
        state.execute(command)
    }

    #[tauri::command]
    fn host_receive(
        state: State<'_, HostState>,
        timeout_ms: Option<u64>,
    ) -> Result<Value, String> {
        state.receive(timeout_ms.unwrap_or(25))
    }

    #[tauri::command]
    fn host_snapshot(state: State<'_, HostState>) -> Result<Value, String> {
        state.snapshot()
    }

    #[tauri::command]
    fn host_close(state: State<'_, HostState>) -> Result<Value, String> {
        state.close()
    }

    #[tauri::command]
    fn feature_host_initialize(
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        state.initialize(config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    fn feature_host_receive(
        state: State<'_, FeatureHostState>,
        _timeout_ms: Option<u64>,
    ) -> Result<Option<HostEvent>, String> {
        state.receive()
    }

    #[tauri::command]
    fn feature_host_resolve_approval(
        state: State<'_, FeatureHostState>,
        resolution: ApprovalResolution,
    ) -> Result<(), String> {
        state.resolve_approval(resolution)
    }

    #[tauri::command]
    fn feature_host_interrupt(
        state: State<'_, FeatureHostState>,
        operation_id: String,
    ) -> Result<(), String> {
        state.interrupt(&operation_id)
    }

    #[tauri::command]
    fn feature_host_close(state: State<'_, FeatureHostState>) -> Result<(), String> {
        state.close()
    }

    pub fn run() {
        tauri::Builder::default()
            .manage(HostState::default())
            .manage(FeatureHostState::default())
            .invoke_handler(tauri::generate_handler![
                host_initialize,
                host_execute,
                host_receive,
                host_snapshot,
                host_close,
                feature_host_initialize,
                feature_host_execute,
                feature_host_receive,
                feature_host_resolve_approval,
                feature_host_interrupt,
                feature_host_close,
            ])
            .run(tauri::generate_context!())
            .expect("Fabushi Tauri Host failed to run");
    }
}

#[cfg(feature = "desktop")]
pub use desktop::run;

#[cfg(test)]
mod tests {
    use super::*;
    use mahayana_host_protocol::ApprovalDecision;
    use mahayana_host_protocol::HostMode;

    #[test]
    fn headless_contract_covers_the_complete_runtime_lifecycle() {
        let state = HostState::default();
        let initialized = state.initialize(None).expect("initialize Host");
        assert_eq!(initialized["initialized"], true);
        assert_eq!(initialized["status"]["runtimeAbiVersion"], 1);

        let status = state
            .execute(json!({"@type": "mahayana.runtime.status"}))
            .expect("execute status");
        assert_eq!(status["runtimeAbiVersion"], 1);
        assert_eq!(status["remoteAgentEnabled"], false);

        let ready = state.receive(10).expect("receive ready event");
        assert_eq!(ready["@type"], "mahayana.runtime.ready");

        let snapshot = state.snapshot().expect("snapshot");
        assert_eq!(snapshot["initialized"], true);

        let closed = state.close().expect("close Host");
        assert_eq!(closed["closed"], true);
        assert!(state
            .execute(json!({"@type": "mahayana.runtime.status"}))
            .expect_err("closed Host must reject commands")
            .contains("not initialized"));
    }

    #[test]
    fn invalid_commands_fail_before_reaching_the_runtime() {
        let state = HostState::default();
        state.initialize(None).expect("initialize Host");
        let error = state
            .execute(json!({"@type": "unknown.command"}))
            .expect_err("unknown command must fail");
        assert!(error.contains("invalid Runtime command"));
    }

    #[test]
    fn headless_feature_commands_execute_the_complete_user_journey_in_rust() {
        let state = FeatureHostState::default();
        let info = state
            .initialize(FeatureHostConfig {
                profile_id: "fast-e2e".into(),
                mode: HostMode::Test,
            })
            .expect("initialize feature Host");
        assert_eq!(info.platform, SurfacePlatform::Tauri);
        assert_eq!(state.receive().expect("ready").unwrap().kind(), "host.ready");

        state
            .execute(FeatureCommand::ChatSend {
                request_id: "chat-1".into(),
                text: "验证极速自动化测试".into(),
            })
            .expect("chat");
        state
            .execute(FeatureCommand::MarketplaceInstall {
                request_id: "install-1".into(),
                mini_app_id: "global-dharma".into(),
            })
            .expect("install");
        state
            .execute(FeatureCommand::MiniAppOpen {
                request_id: "open-1".into(),
                mini_app_id: "global-dharma".into(),
            })
            .expect("open");
        state
            .execute(FeatureCommand::CapabilityRequest {
                request_id: "capability-1".into(),
                mini_app_id: "global-dharma".into(),
                capability: "camera".into(),
                reason: "scan scripture".into(),
            })
            .expect("capability");

        let mut approval_id = None;
        let mut observed = Vec::new();
        while let Some(event) = state.receive().expect("receive event") {
            observed.push(event.kind());
            if let HostEvent::ApprovalRequested {
                approval_id: current,
                ..
            } = event
            {
                approval_id = Some(current);
            }
        }
        assert!(observed.contains(&"chat.message"));
        assert!(observed.contains(&"marketplace.installed"));
        assert!(observed.contains(&"miniapp.opened"));
        state
            .resolve_approval(ApprovalResolution {
                approval_id: approval_id.expect("approval id"),
                decision: ApprovalDecision::AllowOnce,
            })
            .expect("resolve approval");

        let operation_id = state
            .execute(FeatureCommand::RuntimeLongTask {
                request_id: "operation-1".into(),
                label: "index scriptures".into(),
            })
            .expect("long task")
            .operation_id
            .expect("operation id");
        state.interrupt(&operation_id).expect("interrupt");
        state
            .execute(FeatureCommand::SessionClear {
                request_id: "session-1".into(),
            })
            .expect("clear session");

        let tail = std::iter::from_fn(|| state.receive().expect("receive tail"))
            .map(|event| event.kind())
            .collect::<Vec<_>>();
        assert!(tail.contains(&"approval.resolved"));
        assert!(tail.contains(&"operation.started"));
        assert!(tail.contains(&"operation.interrupted"));
        assert!(tail.contains(&"session.cleared"));
        state.close().expect("close");
    }
}
