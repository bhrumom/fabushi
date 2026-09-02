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
struct ProductBackend {
    product: MahayanaProductClient,
}

#[cfg(debug_assertions)]
impl Default for ProductBackend {
    fn default() -> Self {
        Self {
            product: MahayanaProductClient::default(),
        }
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
    let mut session = TestDriverSession::new(ProductBackend::default());

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
}
