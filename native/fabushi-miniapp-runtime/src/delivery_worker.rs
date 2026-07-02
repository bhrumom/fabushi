use crate::client::RuntimeClient;
use crate::dispatcher;
use crate::error::RuntimeError;
use base64::{engine::general_purpose, Engine as _};
use once_cell::sync::Lazy;
use serde_json::{json, Value};
use std::collections::HashSet;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

static RUNNING_WORKERS: Lazy<Mutex<HashSet<u64>>> = Lazy::new(|| Mutex::new(HashSet::new()));

const IDLE_POLL_DELAY: Duration = Duration::from_millis(750);
const SUCCESS_STATUS_MIN: u64 = 200;
const SUCCESS_STATUS_MAX: u64 = 299;

pub(crate) fn ensure_running(client_id: u64, client: Arc<RuntimeClient>) {
    let should_spawn = RUNNING_WORKERS
        .lock()
        .map(|mut workers| workers.insert(client_id))
        .unwrap_or(false);
    if !should_spawn {
        return;
    }

    thread::spawn(move || {
        emit_worker_update(
            &client,
            "updateGlobalDharmaDeliveryWorkerStarted",
            json!({}),
        );
        worker_loop(client_id, client.clone());
        emit_worker_update(
            &client,
            "updateGlobalDharmaDeliveryWorkerStopped",
            json!({}),
        );
        if let Ok(mut workers) = RUNNING_WORKERS.lock() {
            workers.remove(&client_id);
        }
    });
}

fn worker_loop(client_id: u64, client: Arc<RuntimeClient>) {
    while !client.is_closed() {
        let Some(next) = dispatch(
            &client,
            "globalDharma.delivery.nextRetry",
            json!({ "workerClientId": client_id }),
        ) else {
            thread::sleep(IDLE_POLL_DELAY);
            continue;
        };

        if next.get("found").and_then(Value::as_bool) != Some(true) {
            thread::sleep(IDLE_POLL_DELAY);
            continue;
        }

        let job = next.get("job").cloned().unwrap_or(Value::Null);
        process_job(&client, job);
    }
}

fn process_job(client: &Arc<RuntimeClient>, job: Value) {
    let job_id = job
        .get("jobId")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    if job_id.is_empty() {
        emit_worker_error(
            client,
            "invalid_delivery_job",
            "delivery job is missing jobId",
        );
        return;
    }

    let endpoint = match select_endpoint(&job) {
        Ok(endpoint) => endpoint,
        Err(error) => {
            let _ = dispatch(
                client,
                "globalDharma.delivery.markAttempt",
                json!({
                    "jobId": job_id,
                    "success": false,
                    "error": error.to_runtime_event(),
                }),
            );
            return;
        }
    };
    let endpoint_id = endpoint_id(&endpoint);
    emit_worker_update(
        client,
        "updateGlobalDharmaDeliveryWorkerAttempting",
        json!({
            "jobId": job_id,
            "endpointId": endpoint_id,
            "endpoint": endpoint,
        }),
    );

    match send_packet(&job, &endpoint) {
        Ok(receipt_payload) => {
            let _ = dispatch(
                client,
                "globalDharma.delivery.markAttempt",
                json!({
                    "jobId": job_id,
                    "endpointId": endpoint_id,
                    "success": true,
                }),
            );
            let _ = dispatch(
                client,
                "globalDharma.delivery.recordReceipt",
                json!({
                    "jobId": job_id,
                    "endpointId": endpoint_id,
                    "status": "delivered",
                    "payload": receipt_payload,
                }),
            );
        }
        Err(error) => {
            let _ = dispatch(
                client,
                "globalDharma.delivery.markAttempt",
                json!({
                    "jobId": job_id,
                    "endpointId": endpoint_id,
                    "success": false,
                    "retryAfterMs": retry_after_ms(&job, &endpoint),
                    "error": error.to_runtime_event(),
                }),
            );
        }
    }
}

fn send_packet(job: &Value, endpoint: &Value) -> Result<Value, RuntimeError> {
    match endpoint_kind(endpoint).as_str() {
        "http" | "https" => send_http(job, endpoint),
        "udp" => send_udp(job, endpoint),
        "p2p" => Err(RuntimeError::new(
            "delivery_transport_unavailable",
            "global dharma P2P delivery adapter is not wired yet",
        )),
        other => Err(RuntimeError::new(
            "delivery_transport_unknown",
            format!("unsupported delivery transport: {other}"),
        )),
    }
}

fn send_http(job: &Value, endpoint: &Value) -> Result<Value, RuntimeError> {
    let url = required_endpoint_string(endpoint, "url")?;
    let packet = job.get("packet").cloned().unwrap_or(Value::Null);
    let mut params = json!({
        "url": url,
        "method": endpoint
            .get("method")
            .and_then(Value::as_str)
            .unwrap_or("POST"),
        "body": packet_body(&packet),
        "timeoutMs": endpoint
            .get("timeoutMs")
            .and_then(read_u64_value)
            .unwrap_or(15_000),
        "headers": endpoint.get("headers").cloned().unwrap_or_else(|| json!({
            "Content-Type": "application/json",
        })),
    });
    if let Some(max_body_bytes) = endpoint.get("maxBodyBytes").and_then(read_u64_value) {
        params["maxBodyBytes"] = json!(max_body_bytes);
    }

    let response = dispatcher::dispatch_call("network.http.fetch", params)?.response;
    let status_code = response
        .get("statusCode")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    if !(SUCCESS_STATUS_MIN..=SUCCESS_STATUS_MAX).contains(&status_code) {
        return Err(RuntimeError::new(
            "delivery_http_failed",
            format!("HTTP endpoint returned status {status_code}"),
        ));
    }
    Ok(json!({
        "transport": "http",
        "statusCode": status_code,
        "response": response,
    }))
}

fn send_udp(job: &Value, endpoint: &Value) -> Result<Value, RuntimeError> {
    let packet = job.get("packet").cloned().unwrap_or(Value::Null);
    let data_base64 = endpoint
        .get("dataBase64")
        .or_else(|| endpoint.get("data"))
        .and_then(Value::as_str)
        .map(str::to_string)
        .unwrap_or_else(|| general_purpose::STANDARD.encode(packet_body(&packet).as_bytes()));
    let params = if let Some(socket_id) = endpoint.get("socketId").and_then(Value::as_str) {
        json!({
            "socketId": socket_id,
            "host": required_endpoint_string(endpoint, "host")?,
            "port": endpoint.get("port").cloned().unwrap_or(Value::Null),
            "data": data_base64,
        })
    } else {
        json!({
            "host": endpoint
                .get("host")
                .and_then(Value::as_str)
                .unwrap_or("255.255.255.255"),
            "port": endpoint.get("port").cloned().unwrap_or(Value::Null),
            "data": data_base64,
        })
    };

    let response = if endpoint.get("socketId").and_then(Value::as_str).is_some() {
        dispatcher::dispatch_call("network.udp.send", params)?.response
    } else {
        dispatcher::dispatch_call("network.udp.broadcast", params)?.response
    };
    Ok(json!({
        "transport": "udp",
        "response": response,
    }))
}

fn dispatch(client: &Arc<RuntimeClient>, method: &str, params: Value) -> Option<Value> {
    match dispatcher::dispatch_call(method, params) {
        Ok(result) => {
            for update in result.updates {
                let _ = client.enqueue(update);
            }
            Some(result.response)
        }
        Err(error) => {
            emit_worker_error(client, &error.code, &error.message);
            None
        }
    }
}

fn select_endpoint(job: &Value) -> Result<Value, RuntimeError> {
    let endpoints = job.get("endpoints").unwrap_or(&Value::Null);
    if let Some(items) = endpoints.as_array() {
        if items.is_empty() {
            return Err(RuntimeError::new(
                "delivery_endpoint_missing",
                "delivery job has no endpoints",
            ));
        }
        let attempts = job.get("attempts").and_then(Value::as_u64).unwrap_or(0) as usize;
        return Ok(items[attempts % items.len()].clone());
    }
    if endpoints.is_object() || endpoints.is_string() {
        return Ok(endpoints.clone());
    }
    Err(RuntimeError::new(
        "delivery_endpoint_missing",
        "delivery job has no endpoints",
    ))
}

fn endpoint_kind(endpoint: &Value) -> String {
    if endpoint.is_string() {
        return "p2p".to_string();
    }
    endpoint
        .get("transport")
        .or_else(|| endpoint.get("protocol"))
        .or_else(|| endpoint.get("kind"))
        .or_else(|| endpoint.get("type"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_ascii_lowercase)
        .or_else(|| {
            endpoint.get("url").and_then(Value::as_str).map(|url| {
                if url.starts_with("https://") {
                    "https"
                } else {
                    "http"
                }
                .to_string()
            })
        })
        .unwrap_or_else(|| "p2p".to_string())
}

fn endpoint_id(endpoint: &Value) -> String {
    endpoint
        .get("endpointId")
        .or_else(|| endpoint.get("id"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .or_else(|| endpoint.as_str().map(str::to_string))
        .unwrap_or_else(|| endpoint_kind(endpoint))
}

fn retry_after_ms(job: &Value, endpoint: &Value) -> u64 {
    endpoint
        .get("retryAfterMs")
        .or_else(|| job.get("retryAfterMs"))
        .and_then(read_u64_value)
        .unwrap_or(15_000)
}

fn packet_body(packet: &Value) -> String {
    packet
        .as_str()
        .map(str::to_string)
        .unwrap_or_else(|| packet.to_string())
}

fn required_endpoint_string(endpoint: &Value, key: &str) -> Result<String, RuntimeError> {
    endpoint
        .get(key)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or_else(|| {
            RuntimeError::new(
                "invalid_endpoint",
                format!("endpoint {key} cannot be empty"),
            )
        })
}

fn read_u64_value(value: &Value) -> Option<u64> {
    value.as_u64().or_else(|| value.as_str()?.parse().ok())
}

fn emit_worker_update(client: &Arc<RuntimeClient>, update_type: &str, payload: Value) {
    let _ = client.enqueue(json!({
        "@type": update_type,
        "payload": payload,
    }));
}

fn emit_worker_error(client: &Arc<RuntimeClient>, code: &str, message: &str) {
    let _ = client.enqueue(json!({
        "@type": "updateGlobalDharmaDeliveryWorkerError",
        "code": code,
        "message": message,
    }));
}
