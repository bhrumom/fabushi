use mahayana_kernel::KernelError;
use reqwest::Client;
use serde_json::{Value, json};
use std::env;
use url::{Host, Url};

const DEFAULT_SEARCH_ENDPOINT: &str = "https://api.search.tinyfish.ai";
const DEFAULT_FETCH_ENDPOINT: &str = "https://api.fetch.tinyfish.ai";
const DEFAULT_API_KEY_ENV: &str = "TINYFISH_API_KEY";
const MAX_SEARCH_RESULTS: usize = 10;
const MAX_FETCH_URLS: usize = 10;
const MAX_PAGE_TEXT_BYTES: usize = 16 * 1024;

#[derive(Clone)]
pub(crate) struct WebResearchConfig {
    pub(crate) search_endpoint: String,
    pub(crate) fetch_endpoint: String,
    pub(crate) api_key_env: String,
}

impl std::fmt::Debug for WebResearchConfig {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("WebResearchConfig")
            .field("search_endpoint", &self.search_endpoint)
            .field("fetch_endpoint", &self.fetch_endpoint)
            .field("api_key_env", &self.api_key_env)
            .finish_non_exhaustive()
    }
}

impl WebResearchConfig {
    pub(crate) fn tinyfish_from_env() -> Option<Self> {
        env::var(DEFAULT_API_KEY_ENV)
            .ok()
            .filter(|value| !value.trim().is_empty())
            .map(|_| Self {
                search_endpoint: env::var("TINYFISH_SEARCH_ENDPOINT")
                    .unwrap_or_else(|_| DEFAULT_SEARCH_ENDPOINT.to_string()),
                fetch_endpoint: env::var("TINYFISH_FETCH_ENDPOINT")
                    .unwrap_or_else(|_| DEFAULT_FETCH_ENDPOINT.to_string()),
                api_key_env: DEFAULT_API_KEY_ENV.to_string(),
            })
    }

    #[cfg(test)]
    pub(crate) fn for_test(
        search_endpoint: impl Into<String>,
        fetch_endpoint: impl Into<String>,
        api_key_env: impl Into<String>,
    ) -> Self {
        Self {
            search_endpoint: search_endpoint.into(),
            fetch_endpoint: fetch_endpoint.into(),
            api_key_env: api_key_env.into(),
        }
    }

    fn api_key(&self) -> Result<String, KernelError> {
        env::var(&self.api_key_env)
            .ok()
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| {
                KernelError::CapabilityUnavailable(format!(
                    "web research provider is not authenticated; configure {}",
                    self.api_key_env
                ))
            })
    }
}

#[derive(Clone)]
pub(crate) struct WebResearchClient {
    config: WebResearchConfig,
    http: Client,
}

impl WebResearchClient {
    pub(crate) fn new(config: WebResearchConfig) -> Result<Self, KernelError> {
        validate_provider_endpoint(&config.search_endpoint)?;
        validate_provider_endpoint(&config.fetch_endpoint)?;
        let http = Client::builder()
            .build()
            .map_err(|error| KernelError::Backend(format!("web client initialization failed: {error}")))?;
        Ok(Self { config, http })
    }

    pub(crate) async fn search(&self, query: &str, limit: usize) -> Result<Value, KernelError> {
        let query = query.trim();
        if query.is_empty() {
            return Err(KernelError::Backend("web search query must not be empty".into()));
        }
        let limit = limit.clamp(1, MAX_SEARCH_RESULTS);
        let api_key = self.config.api_key()?;
        let endpoint = Url::parse(&self.config.search_endpoint)
            .map_err(|_| KernelError::BackendUnavailable("invalid web search endpoint".into()))?;
        let response = self
            .http
            .get(endpoint)
            .query(&[("query", query)])
            .header("X-API-Key", api_key)
            .send()
            .await
            .map_err(|_| KernelError::BackendUnavailable("web search request failed".into()))?;
        if !response.status().is_success() {
            return Err(KernelError::BackendUnavailable(format!(
                "web search provider returned HTTP {}",
                response.status().as_u16()
            )));
        }
        let payload: Value = response
            .json()
            .await
            .map_err(|_| KernelError::Backend("web search provider returned invalid JSON".into()))?;
        let results = payload
            .get("results")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .take(limit)
            .filter_map(normalize_search_result)
            .collect::<Vec<_>>();
        Ok(json!({
            "provider": "tinyfish",
            "query": query,
            "results": results,
        }))
    }

    pub(crate) async fn fetch(&self, urls: &[String], format: &str) -> Result<Value, KernelError> {
        if urls.is_empty() || urls.len() > MAX_FETCH_URLS {
            return Err(KernelError::Backend(format!(
                "web fetch requires between 1 and {MAX_FETCH_URLS} URLs"
            )));
        }
        let normalized_urls = urls
            .iter()
            .map(|url| validate_public_url(url).map(|parsed| parsed.to_string()))
            .collect::<Result<Vec<_>, _>>()?;
        let format = match format {
            "markdown" | "text" => format,
            _ => {
                return Err(KernelError::Backend(
                    "web fetch format must be markdown or text".into(),
                ));
            }
        };
        let api_key = self.config.api_key()?;
        let endpoint = Url::parse(&self.config.fetch_endpoint)
            .map_err(|_| KernelError::BackendUnavailable("invalid web fetch endpoint".into()))?;
        let response = self
            .http
            .post(endpoint)
            .header("X-API-Key", api_key)
            .json(&json!({"urls": normalized_urls, "format": format}))
            .send()
            .await
            .map_err(|_| KernelError::BackendUnavailable("web fetch request failed".into()))?;
        if !response.status().is_success() {
            return Err(KernelError::BackendUnavailable(format!(
                "web fetch provider returned HTTP {}",
                response.status().as_u16()
            )));
        }
        let payload: Value = response
            .json()
            .await
            .map_err(|_| KernelError::Backend("web fetch provider returned invalid JSON".into()))?;
        let results = payload
            .get("results")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .map(normalize_fetch_result)
            .collect::<Vec<_>>();
        let errors = payload
            .get("errors")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        Ok(json!({
            "provider": "tinyfish",
            "format": format,
            "results": results,
            "errors": errors,
        }))
    }
}

fn normalize_search_result(result: &Value) -> Option<Value> {
    let url = result.get("url").and_then(Value::as_str)?;
    let parsed = validate_public_url(url).ok()?;
    Some(json!({
        "position": result.get("position").cloned().unwrap_or(Value::Null),
        "site_name": result.get("site_name").cloned().unwrap_or(Value::Null),
        "title": result.get("title").cloned().unwrap_or(Value::Null),
        "url": parsed.to_string(),
        "snippet": result.get("snippet").cloned().unwrap_or(Value::Null),
    }))
}

fn normalize_fetch_result(result: &Value) -> Value {
    let text = result
        .get("text")
        .or_else(|| result.get("content"))
        .and_then(Value::as_str)
        .map(|value| truncate_utf8(value, MAX_PAGE_TEXT_BYTES))
        .unwrap_or_default();
    json!({
        "url": result.get("url").cloned().unwrap_or(Value::Null),
        "final_url": result.get("final_url").cloned().unwrap_or(Value::Null),
        "title": result.get("title").cloned().unwrap_or(Value::Null),
        "text": text,
    })
}

fn validate_provider_endpoint(endpoint: &str) -> Result<(), KernelError> {
    let parsed = Url::parse(endpoint)
        .map_err(|_| KernelError::BackendUnavailable("invalid web provider endpoint".into()))?;
    if !matches!(parsed.scheme(), "http" | "https") || parsed.host().is_none() {
        return Err(KernelError::BackendUnavailable(
            "web provider endpoint must be HTTP(S)".into(),
        ));
    }
    Ok(())
}

fn validate_public_url(raw: &str) -> Result<Url, KernelError> {
    let parsed = Url::parse(raw)
        .map_err(|_| KernelError::PolicyDenied("web fetch URL is invalid".into()))?;
    if !matches!(parsed.scheme(), "http" | "https") {
        return Err(KernelError::PolicyDenied(
            "web fetch only allows HTTP(S) URLs".into(),
        ));
    }
    match parsed.host() {
        Some(Host::Ipv4(address)) if address.is_private() || address.is_loopback() || address.is_link_local() => {
            return Err(KernelError::PolicyDenied(
                "web fetch rejects private or local IPv4 targets".into(),
            ));
        }
        Some(Host::Ipv6(address)) if address.is_loopback() || address.is_unspecified() => {
            return Err(KernelError::PolicyDenied(
                "web fetch rejects private or local IPv6 targets".into(),
            ));
        }
        Some(Host::Domain(domain))
            if domain.eq_ignore_ascii_case("localhost")
                || domain.ends_with(".localhost")
                || domain.ends_with(".local") =>
        {
            return Err(KernelError::PolicyDenied(
                "web fetch rejects local hostnames".into(),
            ));
        }
        Some(_) => {}
        None => {
            return Err(KernelError::PolicyDenied(
                "web fetch URL must include a host".into(),
            ));
        }
    }
    Ok(parsed)
}

fn truncate_utf8(value: &str, max_bytes: usize) -> String {
    if value.len() <= max_bytes {
        return value.to_string();
    }
    let mut end = max_bytes;
    while end > 0 && !value.is_char_boundary(end) {
        end -= 1;
    }
    let mut truncated = value[..end].to_string();
    truncated.push_str("\n...[truncated]");
    truncated
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_local_fetch_targets() {
        for url in [
            "http://127.0.0.1/private",
            "http://10.0.0.1/private",
            "http://localhost/private",
            "file:///etc/passwd",
        ] {
            assert!(validate_public_url(url).is_err(), "{url}");
        }
        assert!(validate_public_url("https://example.com/docs").is_ok());
    }

    #[test]
    fn api_key_never_appears_in_debug_output() {
        let key_name = "MAHAYANA_TINYFISH_TEST_SECRET";
        unsafe { env::set_var(key_name, "super-secret-value") };
        let config = WebResearchConfig::for_test(
            "https://api.search.tinyfish.ai",
            "https://api.fetch.tinyfish.ai",
            key_name,
        );
        let debug = format!("{config:?}");
        assert!(!debug.contains("super-secret-value"));
        unsafe { env::remove_var(key_name) };
    }
}
