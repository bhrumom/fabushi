//! Versioned, local-only protocol types for driving Mahayana in test builds.
//!
//! The transport is intentionally surface-neutral. iOS starts with JSONL over
//! stdio/a local socket, while later platform harnesses can reuse the same
//! request, response, event, and correlation-id contract.

use serde::Deserialize;
use serde::Serialize;
use serde_json::Value;
use serde_json::json;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;
use uuid::Uuid;

pub const JSONRPC_VERSION: &str = "2.0";
pub const SCHEMA_VERSION: &str = "mahayana.test-driver.v1";
pub const EVENT_NOTIFICATION_METHOD: &str = "events.emit";
pub const IMPLEMENTED_METHODS: &[&str] = &["health", "schema"];

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DriverRequest {
    pub jsonrpc: String,
    pub schema_version: String,
    pub id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub correlation_id: Option<String>,
    pub method: String,
    #[serde(default)]
    pub params: Value,
}

impl DriverRequest {
    pub fn new(method: impl Into<String>, params: Value) -> Self {
        Self {
            jsonrpc: JSONRPC_VERSION.into(),
            schema_version: SCHEMA_VERSION.into(),
            id: Uuid::new_v4().to_string(),
            correlation_id: None,
            method: method.into(),
            params,
        }
    }

    pub fn validate(&self) -> Result<(), String> {
        if self.jsonrpc != JSONRPC_VERSION {
            return Err(format!(
                "unsupported JSON-RPC version: expected {JSONRPC_VERSION}, got {}",
                self.jsonrpc
            ));
        }
        if self.schema_version != SCHEMA_VERSION {
            return Err(format!(
                "unsupported test driver schema: expected {SCHEMA_VERSION}, got {}",
                self.schema_version
            ));
        }
        if self.id.trim().is_empty() {
            return Err("test driver request id must not be empty".into());
        }
        if self.method.trim().is_empty() {
            return Err("test driver method must not be empty".into());
        }
        Ok(())
    }

    pub fn correlation_id(&self) -> String {
        self.correlation_id
            .clone()
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| Uuid::new_v4().to_string())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DriverError {
    pub code: i64,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DriverResponse {
    pub jsonrpc: String,
    pub schema_version: String,
    #[serde(rename = "type")]
    pub envelope_type: String,
    pub id: String,
    pub request_id: String,
    pub correlation_id: String,
    pub method: String,
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<DriverError>,
}

impl DriverResponse {
    pub fn success(request: &DriverRequest, correlation_id: String, result: Value) -> Self {
        Self {
            jsonrpc: JSONRPC_VERSION.into(),
            schema_version: SCHEMA_VERSION.into(),
            envelope_type: "response".into(),
            id: request.id.clone(),
            request_id: request.id.clone(),
            correlation_id,
            method: request.method.clone(),
            ok: true,
            result: Some(result),
            error: None,
        }
    }

    pub fn failure(
        request: &DriverRequest,
        correlation_id: String,
        code: i64,
        message: impl Into<String>,
    ) -> Self {
        Self {
            jsonrpc: JSONRPC_VERSION.into(),
            schema_version: SCHEMA_VERSION.into(),
            envelope_type: "response".into(),
            id: request.id.clone(),
            request_id: request.id.clone(),
            correlation_id,
            method: request.method.clone(),
            ok: false,
            result: None,
            error: Some(DriverError {
                code,
                message: message.into(),
            }),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DriverEvent {
    pub jsonrpc: String,
    pub schema_version: String,
    #[serde(rename = "type")]
    pub envelope_type: String,
    pub method: String,
    pub request_id: String,
    pub correlation_id: String,
    pub event: String,
    pub timestamp_unix_ms: u64,
    pub outcome: String,
    #[serde(default)]
    pub data: Value,
}

impl DriverEvent {
    pub fn completed(
        request: &DriverRequest,
        correlation_id: String,
        outcome: impl Into<String>,
        data: Value,
    ) -> Self {
        Self {
            jsonrpc: JSONRPC_VERSION.into(),
            schema_version: SCHEMA_VERSION.into(),
            envelope_type: "event".into(),
            method: EVENT_NOTIFICATION_METHOD.into(),
            request_id: request.id.clone(),
            correlation_id,
            event: format!("mahayana.test-driver.{}.completed", request.method),
            timestamp_unix_ms: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis()
                .try_into()
                .unwrap_or(u64::MAX),
            outcome: outcome.into(),
            data,
        }
    }
}

pub fn schema_descriptor() -> Value {
    json!({
        "jsonrpc": JSONRPC_VERSION,
        "schemaVersion": SCHEMA_VERSION,
        "transport": "jsonl",
        "implementedMethods": IMPLEMENTED_METHODS,
        "eventNotificationMethod": EVENT_NOTIFICATION_METHOD,
        "correlationIdRequiredOnResponsesAndEvents": true,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_round_trip_is_versioned_json_rpc() {
        let request = DriverRequest::new("health", json!({}));
        let line = serde_json::to_string(&request).expect("serialize request");
        let decoded: DriverRequest = serde_json::from_str(&line).expect("parse request");

        assert_eq!(decoded.jsonrpc, JSONRPC_VERSION);
        assert_eq!(decoded.schema_version, SCHEMA_VERSION);
        assert_eq!(decoded.method, "health");
        assert!(decoded.validate().is_ok());
    }

    #[test]
    fn response_and_event_share_request_and_correlation_ids() {
        let request = DriverRequest::new("health", json!({}));
        let correlation_id = request.correlation_id();
        let response = DriverResponse::success(
            &request,
            correlation_id.clone(),
            json!({"status": "ready"}),
        );
        let event = DriverEvent::completed(
            &request,
            correlation_id.clone(),
            "success",
            json!({"status": "ready"}),
        );

        assert_eq!(response.request_id, request.id);
        assert_eq!(event.request_id, response.request_id);
        assert_eq!(response.correlation_id, correlation_id);
        assert_eq!(event.correlation_id, response.correlation_id);
        assert_eq!(event.method, EVENT_NOTIFICATION_METHOD);
        assert!(event.timestamp_unix_ms > 0);
    }

    #[test]
    fn invalid_protocol_versions_are_rejected() {
        let mut request = DriverRequest::new("health", json!({}));
        request.jsonrpc = "1.0".into();
        assert!(request.validate().unwrap_err().contains("JSON-RPC"));

        request.jsonrpc = JSONRPC_VERSION.into();
        request.schema_version = "mahayana.test-driver.v0".into();
        assert!(request.validate().unwrap_err().contains("schema"));
    }

    #[test]
    fn schema_descriptor_only_advertises_implemented_methods() {
        let schema = schema_descriptor();
        assert_eq!(schema["jsonrpc"], JSONRPC_VERSION);
        assert_eq!(schema["schemaVersion"], SCHEMA_VERSION);
        assert_eq!(schema["transport"], "jsonl");
        assert_eq!(schema["implementedMethods"], json!(["health", "schema"]));
    }
}
