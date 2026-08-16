//! Thin Tauri shell around the direct `mahayana-host` Rust API.
//!
//! Both state machines are independent from Tauri so ordinary pull requests
//! exercise raw Runtime commands and complete product-level user journeys
//! without a window server or simulator.

#[cfg(feature = "production-runtime")]
use mahayana_core::RuntimeCommand;
#[cfg(feature = "production-runtime")]
use mahayana_core::RuntimeConfig;
use mahayana_feature_host::FeatureHostController;
#[cfg(feature = "production-runtime")]
use mahayana_host::HostCreateConfig;
#[cfg(feature = "production-runtime")]
use mahayana_host::MahayanaHost;
#[cfg(feature = "production-runtime")]
use mahayana_host::default_automation_path;
#[cfg(feature = "production-runtime")]
use mahayana_host::default_product_session_path;
#[cfg(feature = "production-runtime")]
use mahayana_host::default_product_surface_path;
use mahayana_host_protocol::ApprovalResolution;
use mahayana_host_protocol::CommandAccepted;
use mahayana_host_protocol::FeatureCommand;
use mahayana_host_protocol::HostConfig as FeatureHostConfig;
use mahayana_host_protocol::HostEvent;
use mahayana_host_protocol::HostInfo;
use mahayana_host_protocol::SurfacePlatform;
#[cfg(feature = "production-runtime")]
use serde_json::Value;
#[cfg(feature = "production-runtime")]
use serde_json::json;
#[cfg(feature = "production-runtime")]
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::Mutex;
#[cfg(feature = "production-runtime")]
use std::time::Duration;

#[cfg(feature = "production-runtime")]
fn host_config_for_root(root: PathBuf, inherit_installed_plugins: bool) -> HostCreateConfig {
    // Keep the account Keychain identity independent from Runtime/Codex data.
    // This path is stable across app upgrades and avoids an older development
    // signature's secrets ACL blocking the whole native startup.
    let account_root = root.join("account");
    let _ = std::fs::create_dir_all(&account_root);
    let product_session_path = account_root.join("session.json");
    let shared_session_path = default_product_session_path();
    if !product_session_path.exists() && shared_session_path.is_file() {
        let _ = std::fs::copy(&shared_session_path, &product_session_path);
    }
    HostCreateConfig {
        runtime: RuntimeConfig {
            data_dir: Some(root.join("runtime")),
            ..RuntimeConfig::default()
        },
        product_session_path: Some(product_session_path),
        // Connector aliases/tool preferences, private Skills, hidden Bots and
        // listener state are shared with the CLI through the Mahayana app-group
        // store rather than being trapped in Tauri's per-app data directory.
        product_surface_state_path: Some(default_product_surface_path()),
        automation_path: Some(default_automation_path()),
        inherit_installed_plugins: Some(inherit_installed_plugins),
        ..HostCreateConfig::default()
    }
}

#[cfg(feature = "production-runtime")]
#[derive(Default)]
pub struct HostState {
    host: Mutex<Option<MahayanaHost>>,
}

#[cfg(feature = "production-runtime")]
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
    controller: Mutex<Option<Arc<FeatureHostController>>>,
}

impl FeatureHostState {
    pub fn initialize(&self, config: FeatureHostConfig) -> Result<HostInfo, String> {
        let controller = FeatureHostController::create(config, SurfacePlatform::Tauri)
            .map_err(|error| error.to_string())?;
        let info = controller.info();
        *self.lock()? = Some(Arc::new(controller));
        Ok(info)
    }

    #[cfg(feature = "production-runtime")]
    pub fn initialize_with_host_config(
        &self,
        config: FeatureHostConfig,
        host_config: HostCreateConfig,
    ) -> Result<HostInfo, String> {
        let controller = FeatureHostController::create_with_host_config(
            config,
            SurfacePlatform::Tauri,
            host_config,
        )
        .map_err(|error| error.to_string())?;
        let info = controller.info();
        *self.lock()? = Some(Arc::new(controller));
        Ok(info)
    }

    pub fn execute(&self, command: FeatureCommand) -> Result<CommandAccepted, String> {
        self.with_controller(|controller| controller.execute(command))
    }

    pub fn auth_status(&self) -> Result<serde_json::Value, String> {
        self.with_controller(FeatureHostController::auth_status)
    }

    pub fn password_login(
        &self,
        username: String,
        password: String,
    ) -> Result<serde_json::Value, String> {
        self.with_controller(|controller| controller.password_login(username, password))
    }

    pub fn auth_providers(&self) -> Result<serde_json::Value, String> {
        self.with_controller(FeatureHostController::auth_providers)
    }

    pub fn oauth_start(&self, provider: String) -> Result<serde_json::Value, String> {
        self.with_controller(|controller| controller.oauth_start(provider))
    }

    pub fn oauth_poll(&self, attempt_id: String) -> Result<serde_json::Value, String> {
        self.with_controller(|controller| controller.oauth_poll(attempt_id))
    }

    pub fn logout(&self) -> Result<serde_json::Value, String> {
        self.with_controller(FeatureHostController::logout)
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
        let controller = self
            .lock()?
            .as_ref()
            .cloned()
            .ok_or_else(|| "Mahayana feature Host is not initialized".to_string())?;
        operation(&controller).map_err(|error| error.to_string())
    }

    fn lock(
        &self,
    ) -> Result<std::sync::MutexGuard<'_, Option<Arc<FeatureHostController>>>, String> {
        self.controller
            .lock()
            .map_err(|_| "Mahayana feature Host state mutex is poisoned".to_string())
    }
}

#[cfg(feature = "desktop")]
mod desktop {
    use super::FeatureHostState;
    use super::HostState;
    use super::host_config_for_root;
    use mahayana_host_protocol::ApprovalResolution;
    use mahayana_host_protocol::CommandAccepted;
    use mahayana_host_protocol::FeatureCommand;
    use mahayana_host_protocol::HostConfig;
    use mahayana_host_protocol::HostEvent;
    use mahayana_host_protocol::HostInfo;
    use serde_json::Value;
    use tauri::AppHandle;
    use tauri::Manager;
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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_auth_providers(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.auth_providers()
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_browser_login_start(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.browser_login_start()
    }

    #[tauri::command]
    async fn feature_host_oauth_start(
        state: State<'_, FeatureHostState>,
        provider: String,
    ) -> Result<Value, String> {
        state.oauth_start(provider)
    }

    #[tauri::command]
    async fn feature_host_oauth_poll(
        state: State<'_, FeatureHostState>,
        attempt_id: String,
    ) -> Result<Value, String> {
        state.oauth_poll(attempt_id)
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_auth_providers(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.auth_providers()
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_browser_login_start(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.browser_login_start()
    }

    #[tauri::command]
    async fn feature_host_oauth_start(
        state: State<'_, FeatureHostState>,
        provider: String,
    ) -> Result<Value, String> {
        state.oauth_start(provider)
    }

    #[tauri::command]
    async fn feature_host_browser_login_poll(
        state: State<'_, FeatureHostState>,
        attempt_id: String,
    ) -> Result<Value, String> {
        state.browser_login_poll(attempt_id)
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_auth_providers(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.auth_providers()
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_browser_login_start(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.browser_login_start()
    }

    #[tauri::command]
    async fn feature_host_oauth_start(
        state: State<'_, FeatureHostState>,
        provider: String,
    ) -> Result<Value, String> {
        state.oauth_start(provider)
    }

    #[tauri::command]
    async fn feature_host_oauth_poll(
        state: State<'_, FeatureHostState>,
        attempt_id: String,
    ) -> Result<Value, String> {
        state.oauth_poll(attempt_id)
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_auth_providers(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.auth_providers()
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_browser_login_start(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.browser_login_start()
    }

    #[tauri::command]
    async fn feature_host_oauth_start(
        state: State<'_, FeatureHostState>,
        provider: String,
    ) -> Result<Value, String> {
        state.oauth_start(provider)
    }

    #[tauri::command]
    async fn feature_host_browser_login_reopen(
        state: State<'_, FeatureHostState>,
        attempt_id: String,
    ) -> Result<Value, String> {
        state.browser_login_reopen(attempt_id)
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_auth_providers(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.auth_providers()
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_browser_login_start(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.browser_login_start()
    }

    #[tauri::command]
    async fn feature_host_oauth_start(
        state: State<'_, FeatureHostState>,
        provider: String,
    ) -> Result<Value, String> {
        state.oauth_start(provider)
    }

    #[tauri::command]
    async fn feature_host_oauth_poll(
        state: State<'_, FeatureHostState>,
        attempt_id: String,
    ) -> Result<Value, String> {
        state.oauth_poll(attempt_id)
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_auth_providers(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.auth_providers()
    }


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
    fn host_receive(state: State<'_, HostState>, timeout_ms: Option<u64>) -> Result<Value, String> {
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
        app: AppHandle,
        state: State<'_, FeatureHostState>,
        config: HostConfig,
    ) -> Result<HostInfo, String> {
        let root = app
            .path()
            .app_data_dir()
            .map_err(|error| format!("resolve Fabushi app data directory: {error}"))?;
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("create Fabushi app data directory: {error}"))?;
        // Runtime construction stays local and fast. Marketplace discovery and
        // plugin installation are explicit cloud-backed product operations;
        // the signed desktop shell never ships or auto-installs a plugin tree.
        let host_config = host_config_for_root(root, false);
        state.initialize_with_host_config(config, host_config)
    }

    #[tauri::command]
    fn feature_host_execute(
        state: State<'_, FeatureHostState>,
        command: FeatureCommand,
    ) -> Result<CommandAccepted, String> {
        state.execute(command)
    }

    #[tauri::command]
    async fn feature_host_auth_status(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.auth_status()
    }

    #[tauri::command]
    async fn feature_host_password_login(
        state: State<'_, FeatureHostState>,
        username: String,
        password: String,
    ) -> Result<Value, String> {
        state.password_login(username, password)
    }

    #[tauri::command]
    async fn feature_host_browser_login_start(
        state: State<'_, FeatureHostState>,
    ) -> Result<Value, String> {
        state.browser_login_start()
    }

    #[tauri::command]
    async fn feature_host_oauth_start(
        state: State<'_, FeatureHostState>,
        provider: String,
    ) -> Result<Value, String> {
        state.oauth_start(provider)
    }

    #[tauri::command]
    async fn feature_host_browser_login_cancel(
        state: State<'_, FeatureHostState>,
        attempt_id: String,
    ) -> Result<Value, String> {
        state.browser_login_cancel(attempt_id)
    }

    #[tauri::command]
    fn feature_host_window_focused(app: AppHandle) -> bool {
        app.webview_windows()
            .values()
            .any(|window| window.is_focused().unwrap_or(false))
    }

    #[tauri::command]
    fn feature_host_show_notification(title: String, body: String) -> Result<(), String> {
        let title = title.trim();
        let body = body.trim();
        if title.is_empty() || title.chars().count() > 256 || body.chars().count() > 2048 {
            return Err("notification title/body is invalid".to_string());
        }
        if title.contains('\0') || body.contains('\0') {
            return Err("notification text contains a NUL character".to_string());
        }

        #[cfg(target_os = "macos")]
        let status = std::process::Command::new("osascript")
            .env("FABUSHI_NOTIFICATION_TITLE", title)
            .env("FABUSHI_NOTIFICATION_BODY", body)
            .args([
                "-e",
                "display notification (system attribute \"FABUSHI_NOTIFICATION_BODY\") with title (system attribute \"FABUSHI_NOTIFICATION_TITLE\")",
            ])
            .status();

        #[cfg(all(unix, not(target_os = "macos")))]
        let status = std::process::Command::new("notify-send")
            .args([title, body])
            .status();

        #[cfg(target_os = "windows")]
        let status = std::process::Command::new("powershell")
            .env("FABUSHI_NOTIFICATION_TITLE", title)
            .env("FABUSHI_NOTIFICATION_BODY", body)
            .args([
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                r#"[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null; [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null; $xml = New-Object Windows.Data.Xml.Dom.XmlDocument; $xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text></text><text></text></binding></visual></toast>'); $nodes=$xml.GetElementsByTagName('text'); $nodes.Item(0).AppendChild($xml.CreateTextNode($env:FABUSHI_NOTIFICATION_TITLE)) > $null; $nodes.Item(1).AppendChild($xml.CreateTextNode($env:FABUSHI_NOTIFICATION_BODY)) > $null; $toast=[Windows.UI.Notifications.ToastNotification]::new($xml); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Fabushi').Show($toast)"#,
            ])
            .status();

        status
            .map_err(|error| format!("show system notification: {error}"))?
            .success()
            .then_some(())
            .ok_or_else(|| "system notification command failed".to_string())
    }

    #[tauri::command]
    fn feature_host_open_external(url: String) -> Result<(), String> {
        if !url.starts_with("https://") || url.len() > 4096 || url.chars().any(char::is_control) {
            return Err("Fabushi only opens validated HTTPS login URLs".to_string());
        }
        #[cfg(target_os = "macos")]
        let status = std::process::Command::new("open").arg(&url).status();
        #[cfg(target_os = "windows")]
        let status = std::process::Command::new("cmd")
            .args(["/C", "start", "", &url])
            .status();
        #[cfg(all(unix, not(target_os = "macos")))]
        let status = std::process::Command::new("xdg-open").arg(&url).status();
        status
            .map_err(|error| format!("open system browser: {error}"))?
            .success()
            .then_some(())
            .ok_or_else(|| "system browser rejected the login URL".to_string())
    }

    #[tauri::command]
    fn feature_host_open_system_settings(pane: String) -> Result<(), String> {
        #[cfg(target_os = "macos")]
        {
            let url = match pane.as_str() {
                "screen-recording" => {
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                }
                "accessibility" => {
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                }
                _ => return Err("unsupported macOS privacy settings pane".to_string()),
            };
            return std::process::Command::new("/usr/bin/open")
                .arg(url)
                .status()
                .map_err(|error| format!("open macOS privacy settings: {error}"))?
                .success()
                .then_some(())
                .ok_or_else(|| "macOS privacy settings could not be opened".to_string());
        }
        #[cfg(not(target_os = "macos"))]
        {
            let _ = pane;
            Err("system privacy settings shortcut is currently available on macOS only".to_string())
        }
    }

    #[tauri::command]
    async fn feature_host_logout(state: State<'_, FeatureHostState>) -> Result<Value, String> {
        state.logout()
    }

    #[tauri::command]
    fn feature_host_receive(
        state: State<'_, FeatureHostState>,
        timeout_ms: Option<u64>,
    ) -> Result<Option<HostEvent>, String> {
        let _ = timeout_ms;
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
                feature_host_auth_status,
                feature_host_password_login,
                feature_host_auth_providers,
                feature_host_oauth_start,
                feature_host_oauth_poll,
            feature_host_browser_login_start,
            feature_host_browser_login_poll,
            feature_host_browser_login_cancel,
            feature_host_browser_login_reopen,
                feature_host_window_focused,
                feature_host_show_notification,
                feature_host_open_external,
                feature_host_open_system_settings,
                feature_host_logout,
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
    use mahayana_host_protocol::MessageRole;
    use serde::Deserialize;

    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct JourneyContract {
        schema_version: u8,
        features: Vec<JourneyFeature>,
    }

    #[derive(Debug, Deserialize)]
    struct JourneyFeature {
        id: String,
        label: String,
        steps: Vec<JourneyStep>,
    }

    #[derive(Debug, Deserialize)]
    #[serde(tag = "action", rename_all = "camelCase")]
    enum JourneyStep {
        Login {
            username: String,
            password: String,
        },
        OauthLogin {
            provider: String,
        },
        ExpectReady,
        SendChat {
            text: String,
            #[serde(rename = "expectedReply")]
            expected_reply: String,
        },
        InstallMiniApp {
            #[serde(rename = "miniAppId")]
            mini_app_id: String,
        },
        OpenMiniApp {
            #[serde(rename = "miniAppId")]
            mini_app_id: String,
        },
        ApproveCapability {
            #[serde(rename = "miniAppId")]
            mini_app_id: String,
            capability: String,
            decision: ApprovalDecision,
        },
        InterruptOperation {
            label: String,
        },
        ClearSession,
    }

    fn cross_platform_journey_contract() -> JourneyContract {
        serde_json::from_str(include_str!(
            "../../../../contracts/automation/cross-platform-journeys.json"
        ))
        .expect("parse cross-platform journey contract")
    }

    fn drain_events(state: &FeatureHostState) -> Vec<HostEvent> {
        std::iter::from_fn(|| state.receive().expect("receive journey event")).collect()
    }

    #[cfg(feature = "production-runtime")]
    fn isolated_host_config(label: &str) -> HostCreateConfig {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system time")
            .as_nanos();
        let root = std::env::temp_dir().join(format!(
            "fabushi-tauri-{label}-{}-{unique}",
            std::process::id()
        ));
        std::fs::create_dir_all(&root).expect("create isolated Tauri Host root");
        host_config_for_root(root, false)
    }

    #[cfg(feature = "production-runtime")]
    fn encoded_host_config(label: &str) -> Value {
        serde_json::to_value(isolated_host_config(label)).expect("serialize Host config")
    }

    #[cfg(feature = "production-runtime")]
    #[test]
    fn headless_contract_covers_the_complete_runtime_lifecycle() {
        let state = HostState::default();
        let initialized = state
            .initialize(Some(encoded_host_config("lifecycle")))
            .expect("initialize Host");
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
        assert!(
            state
                .execute(json!({"@type": "mahayana.runtime.status"}))
                .expect_err("closed Host must reject commands")
                .contains("not initialized")
        );
    }

    #[cfg(feature = "production-runtime")]
    #[test]
    fn invalid_commands_fail_before_reaching_the_runtime() {
        let state = HostState::default();
        state
            .initialize(Some(encoded_host_config("invalid-command")))
            .expect("initialize Host");
        let error = state
            .execute(json!({"@type": "unknown.command"}))
            .expect_err("unknown command must fail");
        assert!(error.contains("invalid Runtime command"));
    }

    #[test]
    fn headless_feature_commands_execute_the_shared_cross_platform_journeys() {
        let state = FeatureHostState::default();
        let info = state
            .initialize(FeatureHostConfig {
                profile_id: "fast-e2e".into(),
                mode: HostMode::Test,
            })
            .expect("initialize feature Host");
        assert_eq!(info.platform, SurfacePlatform::Tauri);

        let contract = cross_platform_journey_contract();
        assert_eq!(contract.schema_version, 1);
        assert!(!contract.features.is_empty());
        let mut request_sequence = 0_u64;

        for feature in contract.features {
            assert!(!feature.label.is_empty(), "{} has no label", feature.id);
            assert!(!feature.steps.is_empty(), "{} has no steps", feature.id);
            for step in feature.steps {
                request_sequence += 1;
                let request_id = format!("contract-{request_sequence}");
                match step {
                    JourneyStep::Login { username, password } => {
                        let session = state
                            .password_login(username.clone(), password)
                            .expect("password login");
                        assert_eq!(session["loggedIn"], true);
                        assert_eq!(session["user"]["username"], username);
                        assert_eq!(state.auth_status().expect("auth status")["loggedIn"], true);
                    }
                    JourneyStep::OauthLogin { provider } => {
                        let attempt = state.oauth_start(provider.clone()).expect("start OAuth");
                        assert_eq!(attempt["provider"], provider);
                        let result = state
                            .oauth_poll(
                                attempt["attemptId"]
                                    .as_str()
                                    .expect("OAuth attempt id")
                                    .to_string(),
                            )
                            .expect("complete OAuth");
                        assert_eq!(result["status"], "completed");
                        assert_eq!(result["auth"]["loggedIn"], true);
                        assert_eq!(state.auth_status().expect("auth status")["loggedIn"], true);
                    }
                    JourneyStep::ExpectReady => {
                        let event = state.receive().expect("ready").expect("ready event");
                        assert!(matches!(event, HostEvent::HostReady { .. }));
                    }
                    JourneyStep::SendChat {
                        text,
                        expected_reply,
                    } => {
                        state
                            .execute(FeatureCommand::ChatSend {
                                request_id,
                                text,
                                agent_id: None,
                                conversation_id: None,
                                mode: Default::default(),
                                mode_statement: None,
                                model: None,
                                attachments: Vec::new(),
                            })
                            .expect("send chat");
                        assert!(drain_events(&state).iter().any(|event| matches!(
                            event,
                            HostEvent::ChatMessage {
                                role: MessageRole::Assistant,
                                text,
                                ..
                            } if text == &expected_reply
                        )));
                    }
                    JourneyStep::InstallMiniApp { mini_app_id } => {
                        state
                            .execute(FeatureCommand::MarketplaceInstall {
                                request_id,
                                mini_app_id: mini_app_id.clone(),
                            })
                            .expect("install MiniApp");
                        assert!(drain_events(&state).iter().any(|event| matches!(
                            event,
                            HostEvent::MarketplaceInstalled { mini_app_id: id, .. }
                                if id == &mini_app_id
                        )));
                    }
                    JourneyStep::OpenMiniApp { mini_app_id } => {
                        state
                            .execute(FeatureCommand::MiniAppOpen {
                                request_id,
                                mini_app_id: mini_app_id.clone(),
                            })
                            .expect("open MiniApp");
                        assert!(drain_events(&state).iter().any(|event| matches!(
                            event,
                            HostEvent::MiniAppOpened { mini_app_id: id, .. }
                                if id == &mini_app_id
                        )));
                    }
                    JourneyStep::ApproveCapability {
                        mini_app_id,
                        capability,
                        decision,
                    } => {
                        state
                            .execute(FeatureCommand::CapabilityRequest {
                                request_id,
                                mini_app_id: mini_app_id.clone(),
                                capability: capability.clone(),
                                reason: "cross-platform contract".into(),
                            })
                            .expect("request capability");
                        let approval_id = drain_events(&state)
                            .into_iter()
                            .find_map(|event| match event {
                                HostEvent::ApprovalRequested {
                                    approval_id,
                                    mini_app_id: id,
                                    capability: requested,
                                    ..
                                } if id == mini_app_id && requested == capability => {
                                    Some(approval_id)
                                }
                                _ => None,
                            })
                            .expect("matching approval request");
                        state
                            .resolve_approval(ApprovalResolution {
                                approval_id: approval_id.clone(),
                                decision,
                            })
                            .expect("resolve approval");
                        assert!(drain_events(&state).iter().any(|event| matches!(
                            event,
                            HostEvent::ApprovalResolved {
                                approval_id: id,
                                decision: actual,
                                ..
                            } if id == &approval_id && actual == &decision
                        )));
                    }
                    JourneyStep::InterruptOperation { label } => {
                        let operation_id = state
                            .execute(FeatureCommand::RuntimeLongTask {
                                request_id,
                                label: label.clone(),
                            })
                            .expect("start operation")
                            .operation_id
                            .expect("operation id");
                        state.interrupt(&operation_id).expect("interrupt operation");
                        let events = drain_events(&state);
                        assert!(events.iter().any(|event| matches!(
                            event,
                            HostEvent::OperationStarted {
                                operation_id: id,
                                label: actual,
                                interruptible: true,
                                ..
                            } if id == &operation_id && actual == &label
                        )));
                        assert!(events.iter().any(|event| matches!(
                            event,
                            HostEvent::OperationInterrupted { operation_id: id, .. }
                                if id == &operation_id
                        )));
                    }
                    JourneyStep::ClearSession => {
                        state
                            .execute(FeatureCommand::SessionClear { request_id })
                            .expect("clear session");
                        assert!(
                            drain_events(&state)
                                .iter()
                                .any(|event| matches!(event, HostEvent::SessionCleared { .. }))
                        );
                    }
                }
            }
        }
        state.close().expect("close");
    }
}
