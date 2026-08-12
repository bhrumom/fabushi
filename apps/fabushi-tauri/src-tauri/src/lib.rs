//! Thin Tauri shell around the direct `mahayana-host` Rust API.
//!
//! The state machine is independent from Tauri so ordinary pull requests can
//! exercise every command without a window server or simulator. The desktop
//! adapter below only converts Tauri inputs into the same typed state methods.

use mahayana_core::RuntimeCommand;
use mahayana_host::HostCreateConfig;
use mahayana_host::MahayanaHost;
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

#[cfg(feature = "desktop")]
mod desktop {
    use super::HostState;
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

    pub fn run() {
        tauri::Builder::default()
            .manage(HostState::default())
            .invoke_handler(tauri::generate_handler![
                host_initialize,
                host_execute,
                host_receive,
                host_snapshot,
                host_close,
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
}
