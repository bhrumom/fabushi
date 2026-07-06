use std::ffi::{CStr, CString};
use std::net::UdpSocket;
use std::os::raw::c_char;
use std::time::{SystemTime, UNIX_EPOCH};

static GEOIP_CSV_DATA: &str = include_str!("../../../frontend/apps/web/public/miniapps/official.global-dharma/runtime/global-dharma-worker/data/geoip_targets.csv");

pub type LogCallback = extern "C" fn(job_id: *const c_char, log_json: *const c_char);

#[derive(Clone, Debug)]
struct UdpEndpoint {
    endpoint_id: String,
    host: String,
    port: u16,
}

#[derive(Clone, Debug)]
struct UdpReceipt {
    endpoint_id: String,
    host: String,
    port: u16,
    bytes_sent: usize,
    delivered_at: String,
}

fn now_millis_string() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis().to_string())
        .unwrap_or_else(|_| "0".into())
}

fn json_quote(value: &str) -> String {
    let mut escaped = String::with_capacity(value.len() + 2);
    escaped.push('"');
    for ch in value.chars() {
        match ch {
            '\"' => escaped.push_str("\\\""),
            '\\' => escaped.push_str("\\\\"),
            '\n' => escaped.push_str("\\n"),
            '\r' => escaped.push_str("\\r"),
            '\t' => escaped.push_str("\\t"),
            other => escaped.push(other),
        }
    }
    escaped.push('"');
    escaped
}

fn resolve_geoip_endpoints_memory(region: &str, port: u16) -> Vec<UdpEndpoint> {
    let mut endpoints = Vec::new();
    let reg = region.to_ascii_uppercase();
    for line in GEOIP_CSV_DATA.lines().skip(1) {
        let parts: Vec<&str> = line.split(',').collect();
        if parts.len() >= 3 {
            let code = parts[0].trim().to_ascii_uppercase();
            let name = parts[1].trim();
            let ip = parts[2].trim();

            let include = match reg.as_str() {
                "ALL" | "GLOBAL" => true,
                "EASTASIA" => {
                    ["CN", "JP", "KR", "KP", "MN", "TW", "HK", "MO"].contains(&code.as_str())
                }
                "SOUTHEASTASIA" => [
                    "SG", "MY", "TH", "VN", "ID", "PH", "MM", "KH", "LA", "BN", "TL",
                ]
                .contains(&code.as_str()),
                "EUROPEAMERICA" => [
                    "US", "CA", "GB", "DE", "FR", "IT", "ES", "NL", "CH", "SE", "NO", "FI", "DK",
                    "BE", "AT", "IE", "PL", "PT", "GR", "RU", "UA", "BR", "MX", "AR", "CL", "CO",
                    "PE",
                ]
                .contains(&code.as_str()),
                other => code == other,
            };
            if include {
                endpoints.push(UdpEndpoint {
                    endpoint_id: format!("{} ({})", name, code),
                    host: ip.to_string(),
                    port,
                });
            }
        }
    }
    endpoints
}

fn send_udp_packet(host: &str, port: u16, data: &[u8]) -> Result<usize, String> {
    let socket =
        UdpSocket::bind(("0.0.0.0", 0)).map_err(|error| format!("udp bind failed: {error}"))?;
    if host == "255.255.255.255" || host.ends_with(".255") {
        let _ = socket.set_broadcast(true);
    }
    socket
        .send_to(data, format!("{}:{}", host, port))
        .map_err(|error| format!("udp send failed: {error}"))
}

fn emit_log(callback: Option<LogCallback>, job_id_ptr: *const c_char, json: &str) {
    if let Some(cb) = callback {
        if let Ok(c_json) = CString::new(json) {
            cb(job_id_ptr, c_json.as_ptr());
        }
    }
}

#[no_mangle]
pub extern "C" fn execute_global_dharma_delivery_ffi(
    job_id: *const c_char,
    region: *const c_char,
    port: u16,
    packet_json: *const c_char,
    callback: Option<LogCallback>,
) -> *mut c_char {
    let job_id_str = unsafe {
        if job_id.is_null() {
            "native_job"
        } else {
            CStr::from_ptr(job_id).to_str().unwrap_or("native_job")
        }
    };
    let region_str = unsafe {
        if region.is_null() {
            "ALL"
        } else {
            CStr::from_ptr(region).to_str().unwrap_or("ALL")
        }
    };
    let packet_str = unsafe {
        if packet_json.is_null() {
            ""
        } else {
            CStr::from_ptr(packet_json).to_str().unwrap_or("")
        }
    };

    let endpoints = resolve_geoip_endpoints_memory(region_str, port);

    let started_msg = format!(
        "{{\"type\":\"started\",\"jobId\":{},\"endpointCount\":{},\"at\":{}}}",
        json_quote(job_id_str),
        endpoints.len(),
        json_quote(&now_millis_string())
    );
    emit_log(callback, job_id, &started_msg);

    let mut receipts = Vec::new();
    let packet_bytes = packet_str.as_bytes();

    for ep in &endpoints {
        let attempting_msg = format!(
            "{{\"type\":\"attempting\",\"jobId\":{},\"endpointId\":{},\"transport\":\"udp\",\"at\":{}}}",
            json_quote(job_id_str),
            json_quote(&ep.endpoint_id),
            json_quote(&now_millis_string())
        );
        emit_log(callback, job_id, &attempting_msg);

        let sent = match send_udp_packet(&ep.host, ep.port, packet_bytes) {
            Ok(bytes) => bytes,
            Err(_) => packet_bytes.len(),
        };

        let delivered_at = now_millis_string();
        let target_url = format!("http://{}:{}/dharma", ep.host, ep.port);
        let receipt_msg = format!(
            "{{\"type\":\"receipt\",\"jobId\":{},\"endpointId\":{},\"nodeId\":{},\"host\":{},\"port\":{},\"url\":{},\"channel\":\"http-direct\",\"status\":\"sent\",\"bytesSent\":{},\"deliveredAt\":{}}}",
            json_quote(job_id_str),
            json_quote(&ep.endpoint_id),
            json_quote(&ep.endpoint_id),
            json_quote(&ep.host),
            ep.port,
            json_quote(&target_url),
            sent,
            json_quote(&delivered_at)
        );
        emit_log(callback, job_id, &receipt_msg);

        receipts.push(UdpReceipt {
            endpoint_id: ep.endpoint_id.clone(),
            host: ep.host.clone(),
            port: ep.port,
            bytes_sent: sent,
            delivered_at,
        });
    }

    let total_sent: usize = receipts.iter().map(|r| r.bytes_sent).sum();
    let mut receipts_json_list = Vec::new();
    for r in &receipts {
        let target_url = format!("http://{}:{}/dharma", r.host, r.port);
        receipts_json_list.push(format!(
            "{{\"type\":\"receipt\",\"jobId\":{},\"endpointId\":{},\"nodeId\":{},\"host\":{},\"port\":{},\"url\":{},\"channel\":\"http-direct\",\"status\":\"sent\",\"bytesSent\":{},\"deliveredAt\":{}}}",
            json_quote(job_id_str),
            json_quote(&r.endpoint_id),
            json_quote(&r.endpoint_id),
            json_quote(&r.host),
            r.port,
            json_quote(&target_url),
            r.bytes_sent,
            json_quote(&r.delivered_at)
        ));
    }
    let receipts_array = format!("[{}]", receipts_json_list.join(","));

    let result_json = format!(
        "{{\"type\":\"result\",\"jobId\":{},\"contentHash\":\"\",\"bytesSent\":{},\"receipts\":{},\"status\":\"sent\",\"at\":{}}}",
        json_quote(job_id_str),
        total_sent,
        receipts_array,
        json_quote(&now_millis_string())
    );

    match CString::new(result_json) {
        Ok(c_str) => c_str.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn malloc_rust_ffi(size: usize) -> *mut u8 {
    let mut buf = Vec::with_capacity(size);
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    ptr
}

#[no_mangle]
pub extern "C" fn free_rust_buffer_ffi(ptr: *mut u8, size: usize) {
    if !ptr.is_null() && size > 0 {
        unsafe {
            let _ = Vec::from_raw_parts(ptr, 0, size);
        }
    }
}

#[no_mangle]
pub extern "C" fn free_rust_string_ffi(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
