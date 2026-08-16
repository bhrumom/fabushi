use fabushi_tauri_lib::FeatureHostState;
use fabushi_tauri_lib::HostState;
use mahayana_core::RuntimeCommand;
use mahayana_core::RuntimeConfig;
use mahayana_host::HostCreateConfig;
use mahayana_host::default_automation_path;
use mahayana_host::default_product_session_path;
use mahayana_host::default_product_surface_path;
use mahayana_host_protocol::ApprovalResolution;
use mahayana_host_protocol::CommandAccepted;
use mahayana_host_protocol::FeatureCommand;
use mahayana_host_protocol::HostConfig;
use mahayana_host_protocol::HostEvent;
use mahayana_host_protocol::HostInfo;
use serde_json::Value;
use std::path::PathBuf;
use tauri::AppHandle;
use tauri::Manager;
use tauri::State;

fn host_config_for_root(root: PathBuf) -> HostCreateConfig {
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
        product_surface_state_path: Some(default_product_surface_path()),
        automation_path: Some(default_automation_path()),
        // Match the signed desktop shell: marketplace packages must still be
        // installed explicitly and are never inherited from a bundled tree.
        inherit_installed_plugins: Some(false),
        ..HostCreateConfig::default()
    }
}

#[tauri::command]
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
async fn feature_host_auth_providers(state: State<'_, FeatureHostState>) -> Result<Value, String> {
    state.auth_providers()
}

#[tauri::command]
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
async fn feature_host_auth_providers(state: State<'_, FeatureHostState>) -> Result<Value, String> {
    state.auth_providers()
}

#[tauri::command]
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
async fn feature_host_auth_providers(state: State<'_, FeatureHostState>) -> Result<Value, String> {
    state.auth_providers()
}

#[tauri::command]
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
async fn feature_host_auth_providers(state: State<'_, FeatureHostState>) -> Result<Value, String> {
    state.auth_providers()
}

#[tauri::command]
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
async fn feature_host_auth_providers(state: State<'_, FeatureHostState>) -> Result<Value, String> {
    state.auth_providers()
}

#[tauri::command]
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
async fn feature_host_auth_providers(state: State<'_, FeatureHostState>) -> Result<Value, String> {
    state.auth_providers()
}

#[tauri::command]
fn host_initialize(state: State<'_, HostState>, config: Option<Value>) -> Result<Value, String> {
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
    state.initialize_with_host_config(config, host_config_for_root(root))
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
        .plugin(tauri_plugin_wdio_webdriver::init())
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
            feature_host_open_external,
            feature_host_logout,
            feature_host_receive,
            feature_host_resolve_approval,
            feature_host_interrupt,
            feature_host_close,
        ])
        .run(tauri::generate_context!())
        .expect("Fabushi Tauri WebDriver E2E shell failed to run");
}
