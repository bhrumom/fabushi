use crate::product::{MahayanaProductClient, ProductError};
use codex_sdk::{ApprovalMode, Codex, CodexOptions, SandboxMode, ThreadOptions};
use fabushi_miniapp_core::{capabilities, evaluate_method, HostPlatform, PolicyContext};
use serde_json::{json, Value};
use std::{
    collections::BTreeSet,
    fmt, fs,
    path::{Path, PathBuf},
};

const KERNEL_VERSION: &str = env!("CARGO_PKG_VERSION");

/// Shared Rust boundary used by the desktop/mobile shells and the Mahayana
/// command-line binary. Programmatic Codex turns always go through the Rust
/// SDK, which drives the Codex executable bundled with Mahayana over JSONL.
#[derive(Debug, Clone)]
pub struct MahayanaKernel {
    upstream_codex_binary: PathBuf,
    uses_bundled_codex: bool,
    product: MahayanaProductClient,
}

impl Default for MahayanaKernel {
    fn default() -> Self {
        let override_binary = std::env::var_os("MAHAYANA_CODEX_BIN")
            .filter(|value| !value.is_empty())
            .map(PathBuf::from);
        let uses_bundled_codex = override_binary.is_none();
        let upstream_codex_binary = override_binary.unwrap_or_else(|| {
            std::env::current_exe()
                .map(|executable| Self::bundled_codex_binary_for(&executable))
                .unwrap_or_else(|_| PathBuf::from("lib/mahayana/codex"))
        });
        Self {
            upstream_codex_binary,
            uses_bundled_codex,
            product: MahayanaProductClient::default(),
        }
    }
}

impl MahayanaKernel {
    pub fn new(upstream_codex_binary: impl Into<PathBuf>) -> Self {
        Self {
            upstream_codex_binary: upstream_codex_binary.into(),
            uses_bundled_codex: false,
            product: MahayanaProductClient::default(),
        }
    }

    pub fn with_product_client(
        upstream_codex_binary: impl Into<PathBuf>,
        product: MahayanaProductClient,
    ) -> Self {
        Self {
            upstream_codex_binary: upstream_codex_binary.into(),
            uses_bundled_codex: false,
            product,
        }
    }

    /// Resolves the Codex executable that ships in the same Mahayana release.
    /// A Linux archive has `bin/mahayana` and `lib/mahayana/codex`; installers
    /// retain that layout below their selected prefix.
    pub fn bundled_codex_binary_for(executable: &Path) -> PathBuf {
        let executable_dir = executable.parent().unwrap_or_else(|| Path::new("."));
        let directory_name = executable_dir.file_name().and_then(|value| value.to_str());
        let prefix = match directory_name {
            Some("bin") | Some("MacOS") => executable_dir.parent().unwrap_or(executable_dir),
            _ => executable_dir,
        };
        prefix
            .join("lib")
            .join("mahayana")
            .join(platform_executable_name("codex"))
    }

    pub fn upstream_codex_binary(&self) -> &Path {
        &self.upstream_codex_binary
    }

    pub fn uses_bundled_codex(&self) -> bool {
        self.uses_bundled_codex
    }

    pub fn status(&self) -> Value {
        json!({
            "@type": "mahayana.status",
            "version": KERNEL_VERSION,
            "upstreamCodexBinary": self.upstream_codex_binary,
            "mahayanaCliBinary": self.mahayana_cli_binary(),
            "codexDistribution": if self.uses_bundled_codex { "bundled" } else { "explicit-override" },
            "core": "codex-rust-sdk",
            "codexDriver": "codex-client-sdk",
            "codexTransport": "codex exec JSONL",
            "sharedRustModules": [
                "fabushi-telegram-runtime",
                "fabushi-miniapp-runtime",
                "fabushi-miniapp-core",
                "mahayana-product-client",
            ],
            "productApiBaseUrl": self.product.api_base_url(),
            "accountSessionPath": self.product.session_path(),
            "mcpServer": "mahayana mcp-server",
            "globalDharmaMcpServer": "global-dharma-mcp",
        })
    }

    /// Executes a product-neutral Rust request.  This is the single dispatch
    /// point shared by the CLI and any future in-process native shell.
    pub fn execute(&self, request: Value) -> Result<Value, MahayanaKernelError> {
        let request_type = request_type(&request)?;
        match request_type.as_str() {
            "mahayana.status" => Ok(self.status()),
            "mahayana.codex.run" => self.run_codex_blocking(&request),
            "mahayana.telegram.createClient" => Ok(json!({
                "@type": "mahayana.telegram.clientCreated",
                "clientId": fabushi_telegram_runtime::create_client(),
            })),
            "mahayana.telegram.closeClient" => {
                let client_id = required_u64(&request, "clientId")?;
                fabushi_telegram_runtime::close_client(client_id)
                    .map_err(|error| MahayanaKernelError::Telegram(error.to_string()))?;
                Ok(json!({
                    "@type": "mahayana.telegram.clientClosed",
                    "clientId": client_id,
                }))
            }
            "mahayana.telegram.execute" => {
                let client_id = required_u64(&request, "clientId")?;
                let telegram_request = request
                    .get("request")
                    .cloned()
                    .filter(Value::is_object)
                    .ok_or(MahayanaKernelError::InvalidParameter("request"))?;
                let response = fabushi_telegram_runtime::execute_json(
                    client_id,
                    &telegram_request.to_string(),
                );
                let response = serde_json::from_str::<Value>(&response)
                    .map_err(|error| MahayanaKernelError::Telegram(error.to_string()))?;
                Ok(json!({
                    "@type": "mahayana.telegram.response",
                    "clientId": client_id,
                    "response": response,
                }))
            }
            "mahayana.miniapp.execute" => {
                let miniapp_request = request
                    .get("request")
                    .cloned()
                    .filter(Value::is_object)
                    .ok_or(MahayanaKernelError::InvalidParameter("request"))?;
                let response_json =
                    fabushi_miniapp_runtime::execute_json(&miniapp_request.to_string())
                        .map_err(MahayanaKernelError::MiniAppRuntime)?;
                let response = serde_json::from_str::<Value>(&response_json)
                    .map_err(|error| MahayanaKernelError::MiniAppRuntime(error.to_string()))?;
                Ok(json!({
                    "@type": "mahayana.miniapp.response",
                    "response": response,
                }))
            }
            "mahayana.miniapp.evaluate" => self.evaluate_miniapp_method(&request),
            "mahayana.miniapp.inspect" => {
                let path = required_string(&request, "manifestPath")?;
                Ok(self.inspect_miniapp(path)?.into_json())
            }
            "mahayana.miniapp.chat" => self.chat_with_miniapp(&request),
            product_type
                if product_type.starts_with("mahayana.auth.")
                    || product_type.starts_with("mahayana.contacts.")
                    || product_type.starts_with("mahayana.messages.") =>
            {
                self.product
                    .execute(product_type, &request)
                    .map_err(MahayanaKernelError::Product)
            }
            other => Err(MahayanaKernelError::UnsupportedRequest(other.to_string())),
        }
    }

    fn chat_with_miniapp(&self, request: &Value) -> Result<Value, MahayanaKernelError> {
        let miniapp_id = required_string(request, "miniAppId")?;
        let message = required_string(request, "message")?;
        let mut codex_request = json!({
            "prompt": format!(
                "你正在大乘软件中与小程序 `{miniapp_id}` 对话。请把用户输入理解为对该小程序的操作或问题；需要调用大乘小程序工具时就调用，并用中文简洁回复。\n\n用户：{message}"
            ),
            "sandbox": "read-only",
            "approvalPolicy": "on-request",
            "skipGitRepoCheck": true,
        });
        if let Some(thread_id) = optional_string(request, "threadId") {
            codex_request["threadId"] = Value::String(thread_id);
        }
        let mut response = self.run_codex_blocking(&codex_request)?;
        response["@type"] = Value::String("mahayana.miniapp.chatTurn".to_string());
        response["miniAppId"] = Value::String(miniapp_id.to_string());
        Ok(response)
    }

    /// Runs a Codex turn with the Rust SDK instead of passing raw user
    /// arguments to a subprocess. The SDK owns the JSONL contract, thread
    /// resume semantics, model options, and event decoding.
    ///
    /// This synchronous boundary is intentionally kept at the FFI/CLI edge.
    /// Flutter and native hosts invoke it off their UI thread.
    pub fn run_codex_blocking(&self, request: &Value) -> Result<Value, MahayanaKernelError> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|error| MahayanaKernelError::CodexSdk(error.to_string()))?;
        runtime.block_on(self.run_codex(request))
    }

    async fn run_codex(&self, request: &Value) -> Result<Value, MahayanaKernelError> {
        let prompt = required_string(request, "prompt")?.to_string();
        let config = self.mahayana_cli_binary().map(|cli| {
            json!({
                "mcp_servers": {
                    "mahayana": {
                        "command": cli.to_string_lossy(),
                        "args": ["mcp-server"],
                    }
                }
            })
            .as_object()
            .cloned()
            .expect("Mahayana MCP config is an object")
        });
        let options = CodexOptions {
            codex_path_override: Some(self.upstream_codex_binary.to_string_lossy().into_owned()),
            base_url: optional_string(request, "baseUrl"),
            api_key: optional_string(request, "apiKey"),
            config,
            ..Default::default()
        };
        let codex = Codex::new(Some(options))
            .map_err(|error| MahayanaKernelError::CodexSdk(error.to_string()))?;
        let thread_options = ThreadOptions {
            model: optional_string(request, "model"),
            working_directory: optional_string(request, "workingDirectory"),
            sandbox_mode: optional_string(request, "sandbox")
                .map(|value| parse_sandbox_mode(&value))
                .transpose()?,
            approval_policy: optional_string(request, "approvalPolicy")
                .map(|value| parse_approval_mode(&value))
                .transpose()?,
            skip_git_repo_check: request.get("skipGitRepoCheck").and_then(Value::as_bool),
            network_access_enabled: request.get("networkAccessEnabled").and_then(Value::as_bool),
            web_search_enabled: request.get("webSearchEnabled").and_then(Value::as_bool),
            ..Default::default()
        };
        let thread = match optional_string(request, "threadId") {
            Some(thread_id) => codex.resume_thread(thread_id, Some(thread_options)),
            None => codex.start_thread(Some(thread_options)),
        };
        let turn = thread
            .run(prompt, None)
            .await
            .map_err(|error| MahayanaKernelError::CodexSdk(error.to_string()))?;
        let items = serde_json::to_value(turn.items)
            .map_err(|error| MahayanaKernelError::CodexSdk(error.to_string()))?;
        let usage = serde_json::to_value(turn.usage)
            .map_err(|error| MahayanaKernelError::CodexSdk(error.to_string()))?;
        Ok(json!({
            "@type": "mahayana.codex.turn",
            "driver": "codex-client-sdk",
            "threadId": thread.id(),
            "finalResponse": turn.final_response,
            "items": items,
            "usage": usage,
        }))
    }

    fn mahayana_cli_binary(&self) -> Option<PathBuf> {
        if let Some(explicit) = std::env::var_os("MAHAYANA_CLI_BIN")
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
        {
            return Some(explicit);
        }
        if let Ok(current) = std::env::current_exe() {
            if current.file_stem().and_then(|value| value.to_str()) == Some("mahayana") {
                return Some(current);
            }
        }
        let prefix = self
            .upstream_codex_binary
            .parent()
            .and_then(Path::parent)
            .and_then(Path::parent)?;
        [
            prefix
                .join("bin")
                .join(platform_executable_name("mahayana")),
            prefix.join(platform_executable_name("mahayana")),
            prefix
                .join("MacOS")
                .join(platform_executable_name("mahayana")),
        ]
        .into_iter()
        .find(|candidate| candidate.is_file())
    }

    pub fn inspect_miniapp(
        &self,
        manifest_path: impl AsRef<Path>,
    ) -> Result<MiniAppInspection, MahayanaKernelError> {
        let manifest_path = manifest_path.as_ref();
        let raw = fs::read_to_string(manifest_path).map_err(|error| {
            MahayanaKernelError::Manifest(format!("read {}: {error}", manifest_path.display()))
        })?;
        let manifest = serde_json::from_str::<Value>(&raw).map_err(|error| {
            MahayanaKernelError::Manifest(format!("parse {}: {error}", manifest_path.display()))
        })?;
        let object = manifest.as_object().ok_or_else(|| {
            MahayanaKernelError::Manifest("manifest must be a JSON object".to_string())
        })?;

        let id = object
            .get("id")
            .or_else(|| object.get("miniAppId"))
            .and_then(Value::as_str)
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| MahayanaKernelError::Manifest("manifest.id is required".to_string()))?
            .to_string();
        let entry = object
            .get("entry")
            .or_else(|| object.get("entryUrl"))
            .or_else(|| object.get("main"))
            .or_else(|| {
                object
                    .get("runtime")
                    .and_then(Value::as_object)
                    .and_then(|runtime| runtime.get("entry"))
            })
            .and_then(Value::as_str)
            .unwrap_or("")
            .trim()
            .to_string();
        let declared_permissions = object
            .get("permissions")
            .or_else(|| object.get("capabilities"))
            .and_then(Value::as_array)
            .map(|values| {
                values
                    .iter()
                    .filter_map(Value::as_str)
                    .map(str::trim)
                    .filter(|value| !value.is_empty())
                    .map(str::to_string)
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        let known_permissions = capabilities()
            .into_iter()
            .map(|capability| capability.id)
            .collect::<BTreeSet<_>>();
        let unknown_permissions = declared_permissions
            .iter()
            .filter(|permission| !known_permissions.contains(permission.as_str()))
            .cloned()
            .collect();

        Ok(MiniAppInspection {
            manifest_path: manifest_path.to_path_buf(),
            id,
            entry,
            declared_permissions,
            unknown_permissions,
        })
    }

    fn evaluate_miniapp_method(&self, request: &Value) -> Result<Value, MahayanaKernelError> {
        let method = required_string(request, "method")?;
        let declared_permissions = request
            .get("declaredPermissions")
            .and_then(Value::as_array)
            .map(|values| {
                values
                    .iter()
                    .filter_map(Value::as_str)
                    .map(str::to_string)
                    .collect::<BTreeSet<_>>()
            })
            .unwrap_or_default();
        let platform = request
            .get("platform")
            .and_then(Value::as_str)
            .map(HostPlatform::parse)
            .unwrap_or(HostPlatform::Unknown);
        let trusted_official = request
            .get("trustedOfficial")
            .and_then(Value::as_bool)
            .unwrap_or(false);
        let decision = evaluate_method(
            method,
            &PolicyContext {
                declared_permissions,
                platform,
                trusted_official,
            },
        );
        Ok(json!({
            "@type": "mahayana.miniapp.policyDecision",
            "allowed": decision.allowed,
            "status": decision.status.storage_value(),
            "method": decision.method,
            "permission": decision.permission,
            "capability": decision.capability,
            "reason": decision.reason,
        }))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MiniAppInspection {
    pub manifest_path: PathBuf,
    pub id: String,
    pub entry: String,
    pub declared_permissions: Vec<String>,
    pub unknown_permissions: Vec<String>,
}

impl MiniAppInspection {
    pub fn into_json(self) -> Value {
        json!({
            "@type": "mahayana.miniapp.inspection",
            "manifestPath": self.manifest_path,
            "id": self.id,
            "entry": self.entry,
            "declaredPermissions": self.declared_permissions,
            "unknownPermissions": self.unknown_permissions,
            "valid": self.unknown_permissions.is_empty(),
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MahayanaKernelError {
    MissingRequestType,
    InvalidParameter(&'static str),
    UnsupportedRequest(String),
    CodexSdk(String),
    Telegram(String),
    MiniAppRuntime(String),
    Manifest(String),
    Product(ProductError),
}

impl fmt::Display for MahayanaKernelError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingRequestType => write!(formatter, "request must include a non-empty @type"),
            Self::InvalidParameter(parameter) => {
                write!(formatter, "request parameter {parameter} is invalid")
            }
            Self::UnsupportedRequest(request) => {
                write!(formatter, "unsupported Mahayana request: {request}")
            }
            Self::CodexSdk(error) => write!(formatter, "Codex Rust SDK failed: {error}"),
            Self::Telegram(error) => write!(formatter, "telegram runtime failed: {error}"),
            Self::MiniAppRuntime(error) => write!(formatter, "mini-app runtime failed: {error}"),
            Self::Manifest(error) => write!(formatter, "mini-app manifest failed: {error}"),
            Self::Product(error) => write!(formatter, "product command failed: {error}"),
        }
    }
}

impl std::error::Error for MahayanaKernelError {}

fn request_type(request: &Value) -> Result<String, MahayanaKernelError> {
    request
        .get("@type")
        .or_else(|| request.get("type"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or(MahayanaKernelError::MissingRequestType)
}

fn required_string<'a>(
    request: &'a Value,
    name: &'static str,
) -> Result<&'a str, MahayanaKernelError> {
    request
        .get(name)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or(MahayanaKernelError::InvalidParameter(name))
}

fn required_u64(request: &Value, name: &'static str) -> Result<u64, MahayanaKernelError> {
    request
        .get(name)
        .and_then(Value::as_u64)
        .filter(|value| *value > 0)
        .ok_or(MahayanaKernelError::InvalidParameter(name))
}

fn optional_string(request: &Value, name: &str) -> Option<String> {
    request
        .get(name)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
}

fn parse_sandbox_mode(value: &str) -> Result<SandboxMode, MahayanaKernelError> {
    match value {
        "read-only" => Ok(SandboxMode::ReadOnly),
        "workspace-write" => Ok(SandboxMode::WorkspaceWrite),
        "danger-full-access" => Ok(SandboxMode::DangerFullAccess),
        _ => Err(MahayanaKernelError::InvalidParameter("sandbox")),
    }
}

fn parse_approval_mode(value: &str) -> Result<ApprovalMode, MahayanaKernelError> {
    match value {
        "never" => Ok(ApprovalMode::Never),
        "on-request" => Ok(ApprovalMode::OnRequest),
        "on-failure" => Ok(ApprovalMode::OnFailure),
        "untrusted" => Ok(ApprovalMode::Untrusted),
        _ => Err(MahayanaKernelError::InvalidParameter("approvalPolicy")),
    }
}

fn platform_executable_name(name: &str) -> String {
    if cfg!(windows) {
        format!("{name}.exe")
    } else {
        name.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn status_describes_the_single_rust_core() {
        let status = MahayanaKernel::new("codex-test").status();
        assert_eq!(status["core"], "codex-rust-sdk");
        assert_eq!(status["codexDriver"], "codex-client-sdk");
        assert_eq!(status["codexDistribution"], "explicit-override");
        assert_eq!(status["upstreamCodexBinary"], "codex-test");
        assert!(status["sharedRustModules"]
            .as_array()
            .unwrap()
            .iter()
            .any(|value| value == "fabushi-telegram-runtime"));
    }

    #[test]
    fn bundled_codex_path_is_sibling_to_the_mahayana_installation_prefix() {
        let codex =
            MahayanaKernel::bundled_codex_binary_for(Path::new("/opt/mahayana/bin/mahayana"));
        assert_eq!(codex, PathBuf::from("/opt/mahayana/lib/mahayana/codex"));
    }

    #[test]
    fn bundled_codex_path_supports_flat_desktop_bundles() {
        let codex = MahayanaKernel::bundled_codex_binary_for(Path::new(
            "/opt/global-dharma/global_dharma_sharing",
        ));
        assert_eq!(
            codex,
            PathBuf::from("/opt/global-dharma/lib/mahayana/codex")
        );
    }

    #[test]
    fn bundled_codex_path_supports_macos_app_bundles() {
        let codex = MahayanaKernel::bundled_codex_binary_for(Path::new(
            "/Applications/Fabushi.app/Contents/MacOS/global_dharma_sharing",
        ));
        assert_eq!(
            codex,
            PathBuf::from("/Applications/Fabushi.app/Contents/lib/mahayana/codex")
        );
    }

    #[test]
    fn policy_evaluation_uses_the_shared_miniapp_contract() {
        let response = MahayanaKernel::default()
            .execute(json!({
                "@type": "mahayana.miniapp.evaluate",
                "method": "network.http.fetch",
                "declaredPermissions": [],
                "platform": "linux",
                "trustedOfficial": true,
            }))
            .unwrap();
        assert_eq!(response["allowed"], false);
        assert_eq!(response["status"], "denied");
    }

    #[test]
    fn inspection_rejects_unknown_permissions_without_reading_web_code() {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("mahayana-manifest-{nonce}.json"));
        fs::write(
            &path,
            r#"{"miniAppId":"example.web","runtime":{"entry":"index.html"},"permissions":["network.http","not.real"]}"#,
        )
        .unwrap();
        let inspection = MahayanaKernel::default().inspect_miniapp(&path).unwrap();
        fs::remove_file(path).unwrap();
        assert_eq!(inspection.id, "example.web");
        assert_eq!(inspection.unknown_permissions, vec!["not.real"]);
    }

    #[test]
    fn miniapp_requests_use_the_ffi_runtime_dispatcher() {
        let response = MahayanaKernel::default()
            .execute(json!({
                "@type": "mahayana.miniapp.execute",
                "request": {"@type": "runtime.getStatus"},
            }))
            .unwrap();
        assert_eq!(response["response"]["@type"], "runtime.status");
        assert!(fabushi_miniapp_runtime::supported_methods().contains(&"runtime.getStatus"));
    }

    #[cfg(unix)]
    #[test]
    fn codex_turn_is_driven_through_the_rust_sdk_jsonl_transport() {
        use std::os::unix::fs::PermissionsExt;

        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("mahayana-fake-codex-{nonce}.sh"));
        fs::write(
            &path,
            "#!/bin/sh\ncase \"$*\" in\n  *\"exec --experimental-json\"*) ;;\n  *) exit 64 ;;\nesac\ncat >/dev/null\nprintf '%s\\n' '{\"type\":\"thread.started\",\"thread_id\":\"sdk-thread\"}' '{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"id\":\"message-1\",\"text\":\"SDK response\"}}' '{\"type\":\"turn.completed\",\"usage\":{\"input_tokens\":1,\"cached_input_tokens\":0,\"output_tokens\":2}}'\n",
        )
        .unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o700)).unwrap();
        let response = MahayanaKernel::new(&path)
            .run_codex_blocking(&json!({
                "prompt": "hello from Mahayana",
                "sandbox": "read-only",
                "approvalPolicy": "never",
            }))
            .unwrap();
        fs::remove_file(path).unwrap();
        assert_eq!(response["driver"], "codex-client-sdk");
        assert_eq!(response["threadId"], "sdk-thread");
        assert_eq!(response["finalResponse"], "SDK response");
        assert_eq!(response["usage"]["output_tokens"], 2);
    }
}
