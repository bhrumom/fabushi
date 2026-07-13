use fabushi_miniapp_core::{capabilities, evaluate_method, HostPlatform, PolicyContext};
use serde_json::{json, Value};
use std::{
    collections::BTreeSet,
    fmt, fs,
    path::{Path, PathBuf},
};

const KERNEL_VERSION: &str = env!("CARGO_PKG_VERSION");

/// Shared Rust boundary used by the desktop/mobile shells and the Mahayana
/// command-line binary.  It deliberately does not embed an upstream Codex
/// implementation: the caller launches the installed `codex` executable, so
/// upstream updates are inherited without maintaining a source fork.
#[derive(Debug, Clone)]
pub struct MahayanaKernel {
    upstream_codex_binary: PathBuf,
}

impl Default for MahayanaKernel {
    fn default() -> Self {
        let upstream_codex_binary = std::env::var_os("MAHAYANA_CODEX_BIN")
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("codex"));
        Self {
            upstream_codex_binary,
        }
    }
}

impl MahayanaKernel {
    pub fn new(upstream_codex_binary: impl Into<PathBuf>) -> Self {
        Self {
            upstream_codex_binary: upstream_codex_binary.into(),
        }
    }

    pub fn upstream_codex_binary(&self) -> &Path {
        &self.upstream_codex_binary
    }

    pub fn status(&self) -> Value {
        json!({
            "@type": "mahayana.status",
            "version": KERNEL_VERSION,
            "upstreamCodexBinary": self.upstream_codex_binary,
            "core": "upstream-codex-cli",
            "sharedRustModules": [
                "fabushi-telegram-runtime",
                "fabushi-miniapp-runtime",
                "fabushi-miniapp-core",
            ],
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
            other => Err(MahayanaKernelError::UnsupportedRequest(other.to_string())),
        }
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
    Telegram(String),
    MiniAppRuntime(String),
    Manifest(String),
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
            Self::Telegram(error) => write!(formatter, "telegram runtime failed: {error}"),
            Self::MiniAppRuntime(error) => write!(formatter, "mini-app runtime failed: {error}"),
            Self::Manifest(error) => write!(formatter, "mini-app manifest failed: {error}"),
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn status_describes_the_single_rust_core() {
        let status = MahayanaKernel::new("codex-test").status();
        assert_eq!(status["core"], "upstream-codex-cli");
        assert_eq!(status["upstreamCodexBinary"], "codex-test");
        assert!(status["sharedRustModules"]
            .as_array()
            .unwrap()
            .iter()
            .any(|value| value == "fabushi-telegram-runtime"));
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
}
