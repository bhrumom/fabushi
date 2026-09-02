#[cfg(not(debug_assertions))]
compile_error!(
    "mahayana-test-driver is forbidden in release builds; use a Debug/test-signed build"
);

#[cfg(not(debug_assertions))]
fn main() {}

#[cfg(debug_assertions)]
use mahayana_product::MahayanaProductClient;
#[cfg(debug_assertions)]
use mahayana_test_driver_protocol::{
    TestDriverBackend, TestDriverError, TestDriverMethod, TestDriverSession,
};
#[cfg(debug_assertions)]
use serde_json::{Value, json};
#[cfg(debug_assertions)]
use std::io::{self, BufRead, Write};
#[cfg(debug_assertions)]
use std::path::{Path, PathBuf};

#[cfg(debug_assertions)]
const TEST_DRIVER_ROOT_ENV: &str = "MAHAYANA_TEST_DRIVER_ROOT";
#[cfg(debug_assertions)]
const TEST_DRIVER_ROOT_BASENAME: &str = "mahayana-test-driver";

#[cfg(debug_assertions)]
struct ProductBackend {
    product: MahayanaProductClient,
    root: PathBuf,
}

#[cfg(debug_assertions)]
impl ProductBackend {
    fn from_environment() -> Result<Self, TestDriverError> {
        let root = test_driver_root_from_environment()?;
        std::fs::create_dir_all(&root).map_err(|error| {
            TestDriverError::new(
                "test_profile_unavailable",
                format!("failed to create isolated test profile: {error}"),
            )
        })?;
        ensure_safe_test_root(&root)?;
        let product = MahayanaProductClient::new_with_default_api_base_url(
            root.join("session.json"),
            root.join("product-surface.json"),
        );
        Ok(Self { product, root })
    }

    fn reset_profile(&mut self) -> Result<Value, TestDriverError> {
        ensure_safe_test_root(&self.root)?;
        if self.root.exists() {
            std::fs::remove_dir_all(&self.root).map_err(|error| {
                TestDriverError::new(
                    "test_profile_reset_failed",
                    format!("failed to remove isolated test profile: {error}"),
                )
            })?;
        }
        std::fs::create_dir_all(&self.root).map_err(|error| {
            TestDriverError::new(
                "test_profile_reset_failed",
                format!("failed to recreate isolated test profile: {error}"),
            )
        })?;
        self.product = MahayanaProductClient::new_with_default_api_base_url(
            self.root.join("session.json"),
            self.root.join("product-surface.json"),
        );
        Ok(json!({
            "reset": true,
            "profileKind": "isolated-test-driver",
        }))
    }
}

#[cfg(debug_assertions)]
impl TestDriverBackend for ProductBackend {
    fn backend_name(&self) -> &'static str {
        "mahayana-product-core"
    }

    fn execute(
        &mut self,
        method: TestDriverMethod,
        params: Value,
        _correlation_id: &str,
    ) -> Result<Value, TestDriverError> {
        match method {
            TestDriverMethod::ResetProfile => self.reset_profile(),
            TestDriverMethod::LoginTestAccount => {
                reject_inline_test_account_token(&params)?;
                let token = std::env::var("MAHAYANA_TEST_ACCOUNT_TOKEN")
                    .ok()
                    .map(|value| value.trim().to_string())
                    .filter(|value| !value.is_empty())
                    .ok_or_else(|| {
                        TestDriverError::new(
                            "test_account_token_missing",
                            "MAHAYANA_TEST_ACCOUNT_TOKEN is required for loginTestAccount",
                        )
                    })?;
                self.product
                    .store_test_account_session(&token)
                    .map_err(|error| {
                        TestDriverError::new("product_backend_error", error.to_string())
                            .with_details(json!({
                                "operation": TestDriverMethod::LoginTestAccount.as_str(),
                                "tokenSource": "environment",
                            }))
                    })?;
                Ok(json!({
                    "loggedIn": true,
                    "accountKind": "test",
                    "tokenSource": "environment",
                }))
            }
            TestDriverMethod::MarketplaceSearch => {
                let (query, platform) = marketplace_search_args(&params)?;
                self.product
                    .marketplace_browse(Some(query), Some(platform))
                    .map_err(|error| {
                        TestDriverError::new("product_backend_error", error.to_string())
                            .with_details(json!({
                                "operation": TestDriverMethod::MarketplaceSearch.as_str(),
                                "platform": platform,
                            }))
                    })
            }
            other => Err(TestDriverError::new(
                "product_backend_not_wired",
                format!(
                    "{} is not yet wired to its Mahayana product-core operation",
                    other.as_str()
                ),
            )),
        }
    }
}

#[cfg(debug_assertions)]
fn test_driver_root_from_environment() -> Result<PathBuf, TestDriverError> {
    let root = std::env::var_os(TEST_DRIVER_ROOT_ENV)
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| {
            TestDriverError::new(
                "test_profile_root_missing",
                format!("{TEST_DRIVER_ROOT_ENV} must point to an isolated test profile"),
            )
        })?;
    ensure_safe_test_root(&root)?;
    Ok(root)
}

#[cfg(debug_assertions)]
fn ensure_safe_test_root(root: &Path) -> Result<(), TestDriverError> {
    if !root.is_absolute()
        || root.parent().is_none()
        || root.file_name().and_then(|value| value.to_str()) != Some(TEST_DRIVER_ROOT_BASENAME)
    {
        return Err(TestDriverError::new(
            "unsafe_test_profile_root",
            format!(
                "{TEST_DRIVER_ROOT_ENV} must be an absolute path whose final component is {TEST_DRIVER_ROOT_BASENAME}"
            ),
        ));
    }
    match std::fs::symlink_metadata(root) {
        Ok(metadata) if metadata.file_type().is_symlink() => Err(TestDriverError::new(
            "unsafe_test_profile_root",
            "test profile root must not be a symbolic link",
        )),
        Ok(_) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(TestDriverError::new(
            "test_profile_unavailable",
            format!("failed to inspect isolated test profile: {error}"),
        )),
    }
}

#[cfg(debug_assertions)]
fn reject_inline_test_account_token(params: &Value) -> Result<(), TestDriverError> {
    if params.get("token").is_some()
        || params.get("accessToken").is_some()
        || params.get("authorization").is_some()
    {
        return Err(TestDriverError::new(
            "inline_credentials_forbidden",
            "loginTestAccount credentials must come from MAHAYANA_TEST_ACCOUNT_TOKEN, never request params",
        ));
    }
    Ok(())
}

#[cfg(debug_assertions)]
fn marketplace_search_args(params: &Value) -> Result<(&str, &str), TestDriverError> {
    let query = params
        .get("query")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| {
            TestDriverError::new(
                "invalid_params",
                "marketplace.search requires a non-empty query",
            )
        })?;
    let platform = params
        .get("platform")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("ios");
    Ok((query, platform))
}

#[cfg(debug_assertions)]
fn main() {
    if let Err(error) = run_stdio() {
        eprintln!("mahayana-test-driver: {error}");
        std::process::exit(1);
    }
}

#[cfg(debug_assertions)]
fn run_stdio() -> Result<(), String> {
    let stdin = io::stdin();
    let mut stdout = io::BufWriter::new(io::stdout().lock());
    let backend = ProductBackend::from_environment().map_err(|error| error.to_string())?;
    let mut session = TestDriverSession::new(backend);

    for line in stdin.lock().lines() {
        let line = line.map_err(|error| error.to_string())?;
        if line.trim().is_empty() {
            continue;
        }
        let response = session.execute_json_line(&line);
        writeln!(stdout, "{response}").map_err(|error| error.to_string())?;
        stdout.flush().map_err(|error| error.to_string())?;
        if session.shutdown_requested() {
            break;
        }
    }
    Ok(())
}

#[cfg(all(test, debug_assertions))]
mod tests {
    use super::*;

    #[test]
    fn marketplace_search_defaults_to_ios_and_trims_query() {
        let params = json!({"query": "  全球法布施  "});
        let (query, platform) = marketplace_search_args(&params).unwrap();
        assert_eq!(query, "全球法布施");
        assert_eq!(platform, "ios");
    }

    #[test]
    fn marketplace_search_rejects_empty_query() {
        let error = marketplace_search_args(&json!({"query": "   "})).unwrap_err();
        assert_eq!(error.code, "invalid_params");
    }

    #[test]
    fn login_test_account_rejects_inline_token_material() {
        let error = reject_inline_test_account_token(&json!({"token": "must-not-pass"})).unwrap_err();
        assert_eq!(error.code, "inline_credentials_forbidden");
    }

    #[test]
    fn login_test_account_accepts_credential_free_params() {
        reject_inline_test_account_token(&json!({"account": "ci"})).unwrap();
    }

    #[test]
    fn test_profile_root_requires_absolute_dedicated_basename() {
        let relative = PathBuf::from("mahayana-test-driver");
        assert_eq!(
            ensure_safe_test_root(&relative).unwrap_err().code,
            "unsafe_test_profile_root"
        );
        let unsafe_absolute = std::env::temp_dir().join("not-the-driver-root");
        assert_eq!(
            ensure_safe_test_root(&unsafe_absolute).unwrap_err().code,
            "unsafe_test_profile_root"
        );
    }

    #[test]
    fn test_profile_root_accepts_missing_dedicated_absolute_path() {
        let root = std::env::temp_dir()
            .join(format!("mahayana-test-driver-parent-{}", std::process::id()))
            .join(TEST_DRIVER_ROOT_BASENAME);
        assert!(ensure_safe_test_root(&root).is_ok());
    }
}
