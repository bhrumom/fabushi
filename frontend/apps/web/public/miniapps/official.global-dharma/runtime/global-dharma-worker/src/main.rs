use std::env;
use std::fs;
use std::io::{Read, Write};
use std::net::UdpSocket;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const SUCCESS_STATUS_MIN: u16 = 200;
const SUCCESS_STATUS_MAX: u16 = 299;
const UDP_SAFE_DATAGRAM_BYTES: usize = 8 * 1024;
const UDP_CHUNK_PAYLOAD_BYTES: usize = 6 * 1024;
const DEFAULT_DAEMON_LOOP_INTERVAL_MS: u64 = 3_000;
const MIN_DAEMON_LOOP_INTERVAL_MS: u64 = 1_000;
const MAX_DAEMON_LOOP_INTERVAL_MS: u64 = 24 * 60 * 60 * 1_000;
const DEFAULT_EVENT_LIMIT: usize = 120;
const MAX_EVENT_LIMIT: usize = 1_000;

static GEOIP_CSV_DATA: &str = include_str!("../data/geoip_targets.csv");
static DAEMON_JOBS: Mutex<Vec<DaemonJobRuntime>> = Mutex::new(Vec::new());
static DAEMON_EVENTS: Mutex<Vec<DaemonEventRecord>> = Mutex::new(Vec::new());

#[derive(Clone, Debug)]
struct Endpoint {
    transport: String,
    endpoint_id: String,
    url: String,
    method: String,
    host: String,
    port: u16,
    timeout_ms: u64,
    max_body_bytes: usize,
}

#[derive(Clone, Debug)]
struct Receipt {
    endpoint_id: String,
    channel: String,
    status: String,
    bytes_sent: usize,
    status_code: Option<u16>,
    response_bytes: Option<usize>,
}

#[derive(Clone, Debug)]
struct DaemonJobRuntime {
    job_id: String,
    status: String,
    loop_enabled: bool,
    started_at: String,
    last_active_at: String,
    round_count: u64,
    bytes_sent: usize,
    receipt_count: usize,
    last_error: Option<String>,
    stop: Arc<AtomicBool>,
}

#[derive(Clone, Debug)]
struct DaemonEventRecord {
    job_id: String,
    raw_json: String,
}

fn main() {
    if let Err(error) = run() {
        emit_error(&error);
        eprintln!("{error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if let Some(pos) = args
        .iter()
        .position(|arg| arg == "--serve" || arg == "--daemon")
    {
        let port = args
            .get(pos + 1)
            .and_then(|p| p.parse::<u16>().ok())
            .unwrap_or(18888);
        return run_daemon(port);
    }
    let raw_job = read_job_content()?;
    execute_job_payload(&raw_job).map(|_| ())
}

fn run_daemon(port: u16) -> Result<(), String> {
    use std::net::TcpListener;
    let address = format!("127.0.0.1:{port}");
    let listener =
        TcpListener::bind(&address).map_err(|e| format!("bind daemon port {port} failed: {e}"))?;
    emit_raw(&format!(
        "{{\"type\":\"daemon_started\",\"port\":{},\"at\":{}}}",
        port,
        json_quote(&now_millis_string())
    ));
    for stream in listener.incoming() {
        if let Ok(mut stream) = stream {
            thread::spawn(move || {
                let _ = handle_daemon_connection(&mut stream);
            });
        }
    }
    Ok(())
}

fn handle_daemon_connection(stream: &mut std::net::TcpStream) -> Result<(), String> {
    let mut buffer = [0u8; 8192];
    let mut read_bytes = 0;
    loop {
        match stream.read(&mut buffer[read_bytes..]) {
            Ok(0) => break,
            Ok(n) => {
                read_bytes += n;
                if buffer[..read_bytes].windows(4).any(|w| w == b"\r\n\r\n") {
                    break;
                }
                if read_bytes >= buffer.len() {
                    break;
                }
            }
            Err(e) => return Err(format!("read socket error: {e}")),
        }
    }
    let header_str = String::from_utf8_lossy(&buffer[..read_bytes]);
    let mut content_length: usize = 0;
    for line in header_str.lines() {
        if let Some(len_str) = line
            .strip_prefix("Content-Length:")
            .or_else(|| line.strip_prefix("content-length:"))
        {
            content_length = len_str.trim().parse().unwrap_or(0);
        }
    }
    let header_end = buffer[..read_bytes]
        .windows(4)
        .position(|w| w == b"\r\n\r\n")
        .map(|p| p + 4)
        .unwrap_or(read_bytes);

    let mut body_bytes = buffer[header_end..read_bytes].to_vec();
    while body_bytes.len() < content_length {
        let mut chunk = [0u8; 8192];
        match stream.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => body_bytes.extend_from_slice(&chunk[..n]),
            Err(e) => return Err(format!("read body error: {e}")),
        }
    }

    let first_line = header_str.lines().next().unwrap_or("");
    let target = first_line.split_whitespace().nth(1).unwrap_or("/");
    let path = target.split('?').next().unwrap_or("/");
    let query = target.split_once('?').map(|(_, value)| value).unwrap_or("");
    let (response_status, response_json) = if first_line.starts_with("OPTIONS ") {
        ("204 No Content", String::new())
    } else if path == "/status" || path == "/ping" {
        ("200 OK", daemon_status_json(None, 0, 0))
    } else if path == "/jobs" || path == "/jobs/status" || path == "/events" {
        let job_id = query_param(query, "jobId");
        let cursor = query_param(query, "cursor")
            .and_then(|value| value.parse::<usize>().ok())
            .unwrap_or(0);
        let limit = query_param(query, "limit")
            .and_then(|value| value.parse::<usize>().ok())
            .unwrap_or(DEFAULT_EVENT_LIMIT);
        (
            "200 OK",
            daemon_status_json(job_id.as_deref(), cursor, limit),
        )
    } else if path == "/jobs/start" || path == "/loop/start" {
        match String::from_utf8(body_bytes) {
            Ok(body_str) => match start_daemon_job(&body_str) {
                Ok(response) => ("200 OK", response),
                Err(err) => (
                    "500 Internal Server Error",
                    format!("{{\"ok\":false,\"error\":{}}}", json_quote(&err)),
                ),
            },
            Err(err) => (
                "400 Bad Request",
                format!(
                    "{{\"ok\":false,\"error\":{}}}",
                    json_quote(&format!("invalid utf8: {err}"))
                ),
            ),
        }
    } else if path == "/jobs/stop" || path == "/loop/stop" {
        let body_str = String::from_utf8(body_bytes).unwrap_or_default();
        let job_id = json_string(&body_str, "jobId").or_else(|| query_param(query, "jobId"));
        match stop_daemon_job(job_id.as_deref()) {
            Ok(response) => ("200 OK", response),
            Err(err) => (
                "500 Internal Server Error",
                format!("{{\"ok\":false,\"error\":{}}}", json_quote(&err)),
            ),
        }
    } else if path == "/shutdown" || path == "/exit" {
        std::thread::spawn(|| {
            std::thread::sleep(std::time::Duration::from_millis(150));
            std::process::exit(0);
        });
        ("200 OK", "{\"ok\":true,\"status\":\"shutting_down\"}".to_string())
    } else if path == "/send" {
        match String::from_utf8(body_bytes) {
            Ok(body_str) => match execute_job_payload(&body_str) {
                Ok((bytes_sent, receipts)) => {
                    let receipts_json = receipts
                        .iter()
                        .map(|receipt| {
                            format!(
                                "{{\"nodeId\":{},\"endpointId\":{},\"channel\":{},\"status\":{},\"bytesSent\":{},\"deliveredAt\":{}}}",
                                json_quote(&receipt.endpoint_id),
                                json_quote(&receipt.endpoint_id),
                                json_quote(&receipt.channel),
                                json_quote(&receipt.status),
                                receipt.bytes_sent,
                                json_quote(&now_millis_string())
                            )
                        })
                        .collect::<Vec<_>>()
                        .join(",");
                    (
                        "200 OK",
                        format!("{{\"ok\":true,\"bytesSent\":{bytes_sent},\"receiptCount\":{},\"receipts\":[{}]}}", receipts.len(), receipts_json),
                    )
                }
                Err(err) => (
                    "500 Internal Server Error",
                    format!("{{\"ok\":false,\"error\":{}}}", json_quote(&err)),
                ),
            },
            Err(err) => (
                "400 Bad Request",
                format!("{{\"ok\":false,\"error\":{}}}", json_quote(&format!("invalid utf8: {err}"))),
            ),
        }
    } else {
        ("404 Not Found", "{\"error\":\"not_found\"}".to_string())
    };

    let response = format!(
        "HTTP/1.1 {response_status}\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, Accept\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{response_json}",
        response_json.len()
    );
    let _ = stream.write_all(response.as_bytes());
    let _ = stream.flush();
    Ok(())
}

fn start_daemon_job(raw_job: &str) -> Result<String, String> {
    let job_id = json_string(raw_job, "jobId")
        .unwrap_or_else(|| format!("gd_daemon_{}", now_millis_string()));
    let loop_enabled = daemon_job_loop_enabled(raw_job);
    let interval_ms = daemon_job_interval_ms(raw_job);

    stop_daemon_job_by_id(&job_id);
    spawn_daemon_job(
        job_id.clone(),
        raw_job.to_string(),
        loop_enabled,
        interval_ms,
    );

    Ok(format!(
        "{{\"ok\":true,\"daemon\":true,\"jobId\":{},\"status\":\"running\",\"loop\":{},\"persistent\":false,\"storage\":\"memory\",\"intervalMs\":{},\"at\":{}}}",
        json_quote(&job_id),
        loop_enabled,
        interval_ms,
        json_quote(&now_millis_string())
    ))
}

fn spawn_daemon_job(job_id: String, raw_job: String, loop_enabled: bool, interval_ms: u64) {
    let stop = Arc::new(AtomicBool::new(false));
    let started_at = now_millis_string();
    if let Ok(mut jobs) = DAEMON_JOBS.lock() {
        jobs.retain(|job| job.job_id != job_id);
        jobs.push(DaemonJobRuntime {
            job_id: job_id.clone(),
            status: "running".into(),
            loop_enabled,
            started_at: started_at.clone(),
            last_active_at: started_at,
            round_count: 0,
            bytes_sent: 0,
            receipt_count: 0,
            last_error: None,
            stop: stop.clone(),
        });
    }

    emit_job_event(
        &job_id,
        &format!(
            "{{\"type\":\"daemon_job_started\",\"jobId\":{},\"loop\":{},\"intervalMs\":{},\"at\":{}}}",
            json_quote(&job_id),
            loop_enabled,
            interval_ms,
            json_quote(&now_millis_string())
        ),
    );

    thread::spawn(move || {
        let mut round = 0u64;
        loop {
            if stop.load(Ordering::Relaxed) {
                update_daemon_job(&job_id, |job| {
                    job.status = "stopped".into();
                    job.last_active_at = now_millis_string();
                });
                emit_job_event(
                    &job_id,
                    &format!(
                        "{{\"type\":\"daemon_job_stopped\",\"jobId\":{},\"round\":{},\"at\":{}}}",
                        json_quote(&job_id),
                        round,
                        json_quote(&now_millis_string())
                    ),
                );
                break;
            }

            round = round.saturating_add(1);
            update_daemon_job(&job_id, |job| {
                job.status = "running".into();
                job.last_active_at = now_millis_string();
            });
            emit_job_event(
                &job_id,
                &format!(
                    "{{\"type\":\"daemon_round_started\",\"jobId\":{},\"round\":{},\"at\":{}}}",
                    json_quote(&job_id),
                    round,
                    json_quote(&now_millis_string())
                ),
            );

            match execute_job_payload(&raw_job) {
                Ok((bytes_sent, receipts)) => {
                    let receipt_count = receipts.len();
                    update_daemon_job(&job_id, |job| {
                        job.status = if loop_enabled {
                            "running".into()
                        } else {
                            "sent".into()
                        };
                        job.round_count = round;
                        job.bytes_sent = job.bytes_sent.saturating_add(bytes_sent);
                        job.receipt_count = job.receipt_count.saturating_add(receipt_count);
                        job.last_error = None;
                        job.last_active_at = now_millis_string();
                    });
                    emit_job_event(
                        &job_id,
                        &format!(
                            "{{\"type\":\"daemon_round_completed\",\"jobId\":{},\"round\":{},\"bytesSent\":{},\"receiptCount\":{},\"loop\":{},\"at\":{}}}",
                            json_quote(&job_id),
                            round,
                            bytes_sent,
                            receipt_count,
                            loop_enabled,
                            json_quote(&now_millis_string())
                        ),
                    );
                }
                Err(error) => {
                    update_daemon_job(&job_id, |job| {
                        job.status = if loop_enabled {
                            "retrying".into()
                        } else {
                            "failed".into()
                        };
                        job.round_count = round;
                        job.last_error = Some(error.clone());
                        job.last_active_at = now_millis_string();
                    });
                    emit_job_event(
                        &job_id,
                        &format!(
                            "{{\"type\":\"daemon_round_failed\",\"jobId\":{},\"round\":{},\"error\":{},\"loop\":{},\"at\":{}}}",
                            json_quote(&job_id),
                            round,
                            json_quote(&error),
                            loop_enabled,
                            json_quote(&now_millis_string())
                        ),
                    );
                }
            }

            if !loop_enabled {
                break;
            }
            wait_for_next_daemon_round(&stop, interval_ms);
        }
    });
}

fn wait_for_next_daemon_round(stop: &AtomicBool, interval_ms: u64) {
    let mut waited = 0u64;
    while waited < interval_ms {
        if stop.load(Ordering::Relaxed) {
            return;
        }
        let step = (interval_ms - waited).min(500);
        thread::sleep(Duration::from_millis(step));
        waited = waited.saturating_add(step);
    }
}

fn stop_daemon_job(job_id: Option<&str>) -> Result<String, String> {
    let stopped = if let Some(job_id) = job_id {
        stop_daemon_job_by_id(job_id)
    } else {
        stop_all_daemon_jobs()
    };

    Ok(format!(
        "{{\"ok\":true,\"daemon\":true,\"stopped\":{},\"jobId\":{},\"at\":{}}}",
        stopped,
        job_id.map(json_quote).unwrap_or_else(|| "null".into()),
        json_quote(&now_millis_string())
    ))
}

fn stop_daemon_job_by_id(job_id: &str) -> usize {
    let mut count = 0usize;
    if let Ok(mut jobs) = DAEMON_JOBS.lock() {
        for job in jobs.iter_mut().filter(|job| job.job_id == job_id) {
            job.stop.store(true, Ordering::Relaxed);
            job.status = "stopping".into();
            job.last_active_at = now_millis_string();
            count = count.saturating_add(1);
        }
    }
    if count > 0 {
        emit_job_event(
            job_id,
            &format!(
                "{{\"type\":\"daemon_job_stop_requested\",\"jobId\":{},\"at\":{}}}",
                json_quote(job_id),
                json_quote(&now_millis_string())
            ),
        );
    }
    count
}

fn stop_all_daemon_jobs() -> usize {
    let mut count = 0usize;
    if let Ok(mut jobs) = DAEMON_JOBS.lock() {
        for job in jobs.iter_mut() {
            job.stop.store(true, Ordering::Relaxed);
            job.status = "stopping".into();
            job.last_active_at = now_millis_string();
            count = count.saturating_add(1);
        }
    }
    count
}

fn update_daemon_job(job_id: &str, update: impl FnOnce(&mut DaemonJobRuntime)) {
    if let Ok(mut jobs) = DAEMON_JOBS.lock() {
        if let Some(job) = jobs.iter_mut().find(|job| job.job_id == job_id) {
            update(job);
        }
    }
}

fn daemon_job_loop_enabled(raw_job: &str) -> bool {
    json_bool(raw_job, "loop")
        .or_else(|| {
            extract_json_value(raw_job, "packet").and_then(|packet| json_bool(packet, "loop"))
        })
        .unwrap_or(false)
}

fn daemon_job_interval_ms(raw_job: &str) -> u64 {
    json_number(raw_job, "loopIntervalMs")
        .or_else(|| json_number(raw_job, "intervalMs"))
        .unwrap_or(DEFAULT_DAEMON_LOOP_INTERVAL_MS)
        .clamp(MIN_DAEMON_LOOP_INTERVAL_MS, MAX_DAEMON_LOOP_INTERVAL_MS)
}

fn daemon_status_json(job_id: Option<&str>, cursor: usize, limit: usize) -> String {
    let jobs = DAEMON_JOBS
        .lock()
        .map(|jobs| jobs.clone())
        .unwrap_or_default();
    let selected = job_id.and_then(|id| jobs.iter().find(|job| job.job_id == id).cloned());
    let jobs_json = jobs
        .iter()
        .map(daemon_job_json)
        .collect::<Vec<_>>()
        .join(",");
    let (events_json, next_cursor) = if let Some(job_id) = job_id {
        read_job_events(job_id, cursor, limit)
    } else {
        ("[]".into(), cursor)
    };
    format!(
        "{{\"ok\":true,\"status\":\"ok\",\"daemon\":true,\"version\":\"0.4.0\",\"at\":{},\"jobs\":[{}],\"job\":{},\"events\":{},\"cursor\":{},\"source\":\"rust-daemon-master\"}}",
        now_millis_string(),
        jobs_json,
        selected
            .as_ref()
            .map(daemon_job_json)
            .unwrap_or_else(|| "null".into()),
        events_json,
        next_cursor
    )
}

fn daemon_job_json(job: &DaemonJobRuntime) -> String {
    format!(
        "{{\"jobId\":{},\"status\":{},\"loop\":{},\"startedAt\":{},\"lastActiveAt\":{},\"roundCount\":{},\"bytesSent\":{},\"receiptCount\":{},\"lastError\":{}}}",
        json_quote(&job.job_id),
        json_quote(&job.status),
        job.loop_enabled,
        json_quote(&job.started_at),
        json_quote(&job.last_active_at),
        job.round_count,
        job.bytes_sent,
        job.receipt_count,
        job.last_error
            .as_deref()
            .map(json_quote)
            .unwrap_or_else(|| "null".into())
    )
}

fn read_job_events(job_id: &str, cursor: usize, limit: usize) -> (String, usize) {
    let events = DAEMON_EVENTS
        .lock()
        .map(|events| {
            events
                .iter()
                .filter(|event| event.job_id == job_id)
                .cloned()
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let start = cursor.min(events.len());
    let event_limit = limit.clamp(1, MAX_EVENT_LIMIT);
    let end = start.saturating_add(event_limit).min(events.len());
    let events_json = events[start..end]
        .iter()
        .map(|event| event.raw_json.trim())
        .filter(|line| line.starts_with('{') && line.ends_with('}'))
        .collect::<Vec<_>>()
        .join(",");
    (format!("[{}]", events_json), end)
}

fn emit_job_event(job_id: &str, raw_json: &str) {
    emit_raw(raw_json);
    let _ = job_id;
}

fn record_event_from_raw(raw_json: &str) {
    let Some(job_id) = json_string(raw_json, "jobId") else {
        return;
    };
    if let Ok(mut events) = DAEMON_EVENTS.lock() {
        events.push(DaemonEventRecord {
            job_id,
            raw_json: raw_json.to_string(),
        });
        if events.len() > 20_000 {
            let overflow = events.len().saturating_sub(20_000);
            events.drain(0..overflow);
        }
    }
}

fn query_param(query: &str, key: &str) -> Option<String> {
    for part in query.split('&') {
        let (raw_key, raw_value) = part.split_once('=').unwrap_or((part, ""));
        if raw_key == key {
            return Some(url_decode(raw_value));
        }
    }
    None
}

fn url_decode(value: &str) -> String {
    let mut output = String::new();
    let mut bytes = value.as_bytes().iter().copied();
    while let Some(byte) = bytes.next() {
        if byte == b'+' {
            output.push(' ');
        } else if byte == b'%' {
            let hi = bytes.next();
            let lo = bytes.next();
            if let (Some(hi), Some(lo)) = (hi, lo) {
                let hex = [hi, lo];
                if let Ok(hex_str) = std::str::from_utf8(&hex) {
                    if let Ok(decoded) = u8::from_str_radix(hex_str, 16) {
                        output.push(decoded as char);
                        continue;
                    }
                }
            }
            output.push('%');
        } else {
            output.push(byte as char);
        }
    }
    output
}

fn execute_job_payload(raw_job: &str) -> Result<(usize, Vec<Receipt>), String> {
    let job_id = json_string(raw_job, "jobId").unwrap_or_else(|| "global-dharma-worker-job".into());
    let packet_body = extract_json_value(raw_job, "packet")
        .map(str::to_string)
        .unwrap_or_else(|| "null".into());
    let content_hash = json_string(&packet_body, "contentHash").unwrap_or_default();
    let endpoints = parse_endpoints(raw_job)?;
    let mut receipts = Vec::new();

    emit_raw(&format!(
        "{{\"type\":\"started\",\"jobId\":{},\"endpointCount\":{},\"at\":{}}}",
        json_quote(&job_id),
        endpoints.len(),
        json_quote(&now_millis_string())
    ));

    for endpoint in endpoints {
        emit_raw(&format!(
            "{{\"type\":\"attempting\",\"jobId\":{},\"endpointId\":{},\"transport\":{},\"at\":{}}}",
            json_quote(&job_id),
            json_quote(&endpoint.endpoint_id),
            json_quote(&endpoint.transport),
            json_quote(&now_millis_string())
        ));
        let receipt = send_to_endpoint(&endpoint, &packet_body)?;
        emit_receipt(&job_id, &receipt);
        receipts.push(receipt);

        // 遵照用户的绝对要求：不要并行发送，逐个顺序平稳投递
        std::thread::sleep(std::time::Duration::from_millis(6));
    }

    let bytes_sent = receipts
        .iter()
        .map(|receipt| receipt.bytes_sent)
        .sum::<usize>();
    emit_result(&job_id, &content_hash, bytes_sent, &receipts);
    Ok((bytes_sent, receipts))
}

fn send_to_endpoint(endpoint: &Endpoint, packet_body: &str) -> Result<Receipt, String> {
    match endpoint.transport.as_str() {
        "http" | "https" => send_http(endpoint, packet_body),
        "udp" => send_udp(endpoint, packet_body),
        other => Err(format!("unsupported endpoint transport: {other}")),
    }
}

fn send_http(endpoint: &Endpoint, packet_body: &str) -> Result<Receipt, String> {
    if endpoint.url.is_empty() {
        return Err("http endpoint is missing url".into());
    }
    let timeout_seconds = ((endpoint.timeout_ms + 999) / 1000).clamp(1, 120);
    let mut command = Command::new("curl");
    command
        .arg("-sS")
        .arg("-L")
        .arg("--max-time")
        .arg(timeout_seconds.to_string())
        .arg("-X")
        .arg(&endpoint.method)
        .arg("-H")
        .arg("Content-Type: application/json")
        .arg("-H")
        .arg("Accept: application/json")
        .arg("-H")
        .arg("User-Agent: FabushiMcpApp/GlobalDharmaWorker")
        .arg("-w")
        .arg("\n%{http_code}")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    let sends_body = endpoint.method != "GET" && endpoint.method != "HEAD";
    if sends_body {
        command.arg("--data-binary").arg("@-").stdin(Stdio::piped());
    }
    command.arg(&endpoint.url);

    let mut child = command
        .spawn()
        .map_err(|error| format!("spawn curl failed: {error}"))?;
    if sends_body {
        let mut stdin = child
            .stdin
            .take()
            .ok_or_else(|| "curl stdin was not opened".to_string())?;
        stdin
            .write_all(packet_body.as_bytes())
            .map_err(|error| format!("write curl body failed: {error}"))?;
    }
    let output = child
        .wait_with_output()
        .map_err(|error| format!("wait curl failed: {error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    if !output.status.success() {
        return Err(format!(
            "curl failed for {}: {}",
            endpoint.url,
            stderr.trim()
        ));
    }
    let (body, status_code) = parse_curl_status(&stdout)?;
    if body.as_bytes().len() > endpoint.max_body_bytes {
        return Err(format!(
            "http response exceeded {} bytes",
            endpoint.max_body_bytes
        ));
    }
    if !(SUCCESS_STATUS_MIN..=SUCCESS_STATUS_MAX).contains(&status_code) {
        return Err(format!(
            "http endpoint {} returned {}",
            endpoint.url, status_code
        ));
    }
    Ok(Receipt {
        endpoint_id: endpoint.endpoint_id.clone(),
        channel: "rust-http".into(),
        status: "delivered".into(),
        bytes_sent: packet_body.as_bytes().len(),
        status_code: Some(status_code),
        response_bytes: Some(body.as_bytes().len()),
    })
}

fn send_udp(endpoint: &Endpoint, packet_body: &str) -> Result<Receipt, String> {
    let socket =
        UdpSocket::bind(("0.0.0.0", 0)).map_err(|error| format!("udp bind failed: {error}"))?;
    if endpoint.host == "255.255.255.255" || endpoint.host.ends_with(".255") {
        socket
            .set_broadcast(true)
            .map_err(|error| format!("udp broadcast failed: {error}"))?;
    }
    let target = format!("{}:{}", endpoint.host, endpoint.port);
    let datagrams = udp_datagrams(packet_body);
    let mut sent_bytes = 0usize;
    for datagram in datagrams {
        let mut retries = 40;
        let mut delay = std::time::Duration::from_millis(2);
        loop {
            match socket.send_to(datagram.as_bytes(), &target) {
                Ok(bytes) => {
                    sent_bytes = sent_bytes.saturating_add(bytes);
                    // 绝不并行与突发，逐个分包顺序发，给物理网口缓冲充足时间
                    std::thread::sleep(std::time::Duration::from_micros(1500));
                    break;
                }
                Err(error) => {
                    let os_err = error.raw_os_error();
                    let is_buffer_busy = os_err == Some(55)
                        || os_err == Some(105)
                        || os_err == Some(10055)
                        || os_err == Some(11)
                        || error.kind() == std::io::ErrorKind::WouldBlock;
                    if is_buffer_busy && retries > 0 {
                        retries -= 1;
                        std::thread::sleep(delay);
                        if delay < std::time::Duration::from_millis(30) {
                            delay = delay.saturating_mul(2);
                        }
                        continue;
                    }
                    return Err(format!("udp send failed: {error}"));
                }
            }
        }
    }
    Ok(Receipt {
        endpoint_id: endpoint.endpoint_id.clone(),
        channel: "udp".into(),
        status: "sent".into(),
        bytes_sent: sent_bytes,
        status_code: None,
        response_bytes: None,
    })
}

fn udp_datagrams(packet_body: &str) -> Vec<String> {
    let packet_bytes = packet_body.as_bytes().len();
    if packet_bytes <= UDP_SAFE_DATAGRAM_BYTES {
        return vec![packet_body.to_string()];
    }

    let content_hash = json_string(packet_body, "contentHash").unwrap_or_default();
    let chunks = split_utf8_chunks(packet_body, UDP_CHUNK_PAYLOAD_BYTES);
    let chunk_count = chunks.len();
    chunks
        .into_iter()
        .enumerate()
        .map(|(index, payload)| {
            format!(
                "{{\"type\":\"global_dharma_delivery_chunk\",\"contentHash\":{},\"chunkIndex\":{},\"chunkCount\":{},\"totalBytes\":{},\"encoding\":\"utf8-json\",\"payload\":{}}}",
                json_quote(&content_hash),
                index,
                chunk_count,
                packet_bytes,
                json_quote(&payload)
            )
        })
        .collect()
}

fn split_utf8_chunks(value: &str, max_bytes: usize) -> Vec<String> {
    let max_bytes = max_bytes.max(1);
    let mut chunks = Vec::new();
    let mut start = 0usize;
    let mut current_bytes = 0usize;

    for (index, ch) in value.char_indices() {
        let char_bytes = ch.len_utf8();
        if index > start && current_bytes + char_bytes > max_bytes {
            chunks.push(value[start..index].to_string());
            start = index;
            current_bytes = 0;
        }
        current_bytes += char_bytes;
    }

    if start < value.len() {
        chunks.push(value[start..].to_string());
    }
    if chunks.is_empty() {
        chunks.push(String::new());
    }
    chunks
}

fn resolve_geoip_endpoints(region: &str, port: u16) -> Vec<Endpoint> {
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
                let endpoint_id = format!("{} ({})", name, code);
                endpoints.push(Endpoint {
                    transport: "udp".into(),
                    endpoint_id,
                    url: String::new(),
                    method: "POST".into(),
                    host: ip.to_string(),
                    port,
                    timeout_ms: 30_000,
                    max_body_bytes: 2 * 1024 * 1024,
                });
            }
        }
    }
    endpoints
}

fn parse_endpoints(raw_job: &str) -> Result<Vec<Endpoint>, String> {
    let use_geoip = json_bool(raw_job, "useGeoIp").unwrap_or(false);
    let region = json_string(raw_job, "region").unwrap_or_else(|| "all".into());
    let port = json_number(raw_job, "port").unwrap_or(9_999).min(65_535) as u16;

    let mut objects = Vec::new();
    if let Some(raw_endpoints) = extract_json_value(raw_job, "endpoints") {
        if let Ok(objs) = split_endpoint_objects(raw_endpoints) {
            objects = objs;
        }
    }

    if use_geoip || objects.is_empty() {
        let geo_endpoints = resolve_geoip_endpoints(&region, port);
        if !geo_endpoints.is_empty() {
            return Ok(geo_endpoints);
        }
    }

    if objects.is_empty() {
        return Err("job endpoints array is empty".into());
    }
    Ok(objects
        .into_iter()
        .map(|raw| {
            let transport = json_string(raw, "transport")
                .unwrap_or_else(|| {
                    if json_string(raw, "url").is_some() {
                        "http"
                    } else {
                        "udp"
                    }
                    .into()
                })
                .to_ascii_lowercase();
            let url = json_string(raw, "url").unwrap_or_default();
            let host = json_string(raw, "host").unwrap_or_else(|| "255.255.255.255".into());
            let port = json_number(raw, "port").unwrap_or(9_999).min(65_535) as u16;
            let endpoint_id = json_string(raw, "endpointId").unwrap_or_else(|| {
                if !url.is_empty() {
                    url.clone()
                } else {
                    format!("{host}:{port}")
                }
            });
            Endpoint {
                transport,
                endpoint_id,
                url,
                method: json_string(raw, "method")
                    .unwrap_or_else(|| "POST".into())
                    .to_ascii_uppercase(),
                host,
                port,
                timeout_ms: json_number(raw, "timeoutMs").unwrap_or(30_000),
                max_body_bytes: json_number(raw, "maxBodyBytes").unwrap_or(2 * 1024 * 1024)
                    as usize,
            }
        })
        .collect())
}

fn split_endpoint_objects(raw: &str) -> Result<Vec<&str>, String> {
    let trimmed = raw.trim();
    if trimmed.starts_with('{') {
        return Ok(vec![trimmed]);
    }
    if !trimmed.starts_with('[') {
        return Err("endpoints must be an object or array".into());
    }
    let mut objects = Vec::new();
    let mut index = 1;
    while index < trimmed.len() {
        index = skip_ws_and_commas(trimmed, index);
        if index >= trimmed.len() || trimmed.as_bytes()[index] == b']' {
            break;
        }
        if trimmed.as_bytes()[index] != b'{' {
            return Err("endpoint array contains a non-object value".into());
        }
        let end =
            balanced_end(trimmed, index).ok_or_else(|| "unclosed endpoint object".to_string())?;
        objects.push(&trimmed[index..end]);
        index = end;
    }
    Ok(objects)
}

fn extract_json_value<'a>(raw: &'a str, key: &str) -> Option<&'a str> {
    let pattern = format!("\"{key}\":");
    let mut start = raw.find(&pattern)? + pattern.len();
    start = skip_ws(raw, start);
    let first = *raw.as_bytes().get(start)?;
    if first == b'{' || first == b'[' {
        let end = balanced_end(raw, start)?;
        return Some(&raw[start..end]);
    }
    if first == b'"' {
        let end = string_end(raw, start)?;
        return Some(&raw[start..end]);
    }
    let end = raw[start..]
        .find([',', '}', ']'])
        .map(|offset| start + offset)
        .unwrap_or(raw.len());
    Some(raw[start..end].trim())
}

fn balanced_end(raw: &str, start: usize) -> Option<usize> {
    let open = *raw.as_bytes().get(start)?;
    let close = match open {
        b'{' => b'}',
        b'[' => b']',
        _ => return None,
    };
    let mut depth = 0usize;
    let mut in_string = false;
    let mut escaped = false;
    for (offset, byte) in raw.as_bytes()[start..].iter().enumerate() {
        if in_string {
            if escaped {
                escaped = false;
            } else if *byte == b'\\' {
                escaped = true;
            } else if *byte == b'"' {
                in_string = false;
            }
            continue;
        }
        if *byte == b'"' {
            in_string = true;
        } else if *byte == open {
            depth += 1;
        } else if *byte == close {
            depth = depth.saturating_sub(1);
            if depth == 0 {
                return Some(start + offset + 1);
            }
        }
    }
    None
}

fn string_end(raw: &str, start: usize) -> Option<usize> {
    let mut escaped = false;
    for (offset, byte) in raw.as_bytes()[start + 1..].iter().enumerate() {
        if escaped {
            escaped = false;
        } else if *byte == b'\\' {
            escaped = true;
        } else if *byte == b'"' {
            return Some(start + offset + 2);
        }
    }
    None
}

fn json_string(raw: &str, key: &str) -> Option<String> {
    let value = extract_json_value(raw, key)?.trim();
    if !value.starts_with('"') || !value.ends_with('"') {
        return None;
    }
    Some(unquote_json_string(value))
}

fn json_number(raw: &str, key: &str) -> Option<u64> {
    extract_json_value(raw, key)?.trim().parse::<u64>().ok()
}

fn json_bool(raw: &str, key: &str) -> Option<bool> {
    let val = extract_json_value(raw, key)?.trim();
    if val == "true" {
        Some(true)
    } else if val == "false" {
        Some(false)
    } else {
        None
    }
}

fn unquote_json_string(value: &str) -> String {
    let inner = &value[1..value.len().saturating_sub(1)];
    let mut output = String::new();
    let mut chars = inner.chars();
    while let Some(ch) = chars.next() {
        if ch != '\\' {
            output.push(ch);
            continue;
        }
        match chars.next() {
            Some('"') => output.push('"'),
            Some('\\') => output.push('\\'),
            Some('/') => output.push('/'),
            Some('n') => output.push('\n'),
            Some('r') => output.push('\r'),
            Some('t') => output.push('\t'),
            Some('b') => output.push('\u{0008}'),
            Some('f') => output.push('\u{000c}'),
            Some('u') => {
                let code = chars.by_ref().take(4).collect::<String>();
                if let Ok(value) = u16::from_str_radix(&code, 16) {
                    if let Some(decoded) = char::from_u32(value as u32) {
                        output.push(decoded);
                    }
                }
            }
            Some(other) => output.push(other),
            None => break,
        }
    }
    output
}

fn parse_curl_status(stdout: &str) -> Result<(&str, u16), String> {
    let trimmed = stdout.trim_end_matches(['\r', '\n']);
    let split = trimmed
        .rfind('\n')
        .ok_or_else(|| "curl output did not include an HTTP status code".to_string())?;
    let body = &trimmed[..split];
    let status = trimmed[split + 1..]
        .trim()
        .parse::<u16>()
        .map_err(|error| format!("parse curl status failed: {error}"))?;
    Ok((body, status))
}

fn decode_base64(input: &str) -> Result<Vec<u8>, String> {
    let mut out = Vec::new();
    let mut buffer = 0u32;
    let mut bits = 0;

    for byte in input.bytes() {
        if byte == b'=' {
            break;
        }
        let val = match byte {
            b'A'..=b'Z' => byte - b'A',
            b'a'..=b'z' => byte - b'a' + 26,
            b'0'..=b'9' => byte - b'0' + 52,
            b'+' | b'-' => 62,
            b'/' | b'_' => 63,
            b' ' | b'\r' | b'\n' | b'\t' => continue,
            _ => return Err(format!("invalid base64 char: {}", byte as char)),
        };
        buffer = (buffer << 6) | (val as u32);
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((buffer >> bits) as u8);
            buffer &= (1 << bits) - 1;
        }
    }
    Ok(out)
}

fn read_job_content() -> Result<String, String> {
    let args = env::args().collect::<Vec<_>>();
    if let Some(pair) = args.windows(2).find(|pair| pair[0] == "--job-file") {
        let val = &pair[1];
        if let Some(base64_str) = val
            .strip_prefix("memory://job:")
            .or_else(|| val.strip_prefix("memory://"))
        {
            let bytes = decode_base64(base64_str)?;
            String::from_utf8(bytes).map_err(|e| format!("decode utf8 failed: {e}"))
        } else if val == "-" || val == "stdin" || val == "memory://stdin" {
            let mut content = String::new();
            std::io::stdin()
                .read_to_string(&mut content)
                .map_err(|error| format!("read stdin failed: {error}"))?;
            Ok(content)
        } else {
            fs::read_to_string(val).map_err(|error| format!("read job file failed: {error}"))
        }
    } else if let Some(pair) = args.windows(2).find(|pair| pair[0] == "--job-data") {
        let val = &pair[1];
        if let Some(base64_str) = val
            .strip_prefix("memory://job:")
            .or_else(|| val.strip_prefix("memory://"))
        {
            let bytes = decode_base64(base64_str)?;
            String::from_utf8(bytes).map_err(|e| format!("decode utf8 failed: {e}"))
        } else if val.starts_with('{') {
            Ok(val.clone())
        } else {
            let bytes = decode_base64(val)?;
            String::from_utf8(bytes).map_err(|e| format!("decode utf8 failed: {e}"))
        }
    } else {
        let mut content = String::new();
        std::io::stdin()
            .read_to_string(&mut content)
            .map_err(|error| format!("read stdin failed: {error}"))?;
        if content.trim().is_empty() {
            Err("missing required argument --job-file or stdin content".into())
        } else {
            Ok(content)
        }
    }
}

#[allow(dead_code)]
fn read_arg_value(name: &str) -> Result<String, String> {
    let args = env::args().collect::<Vec<_>>();
    args.windows(2)
        .find(|pair| pair[0] == name)
        .map(|pair| pair[1].clone())
        .ok_or_else(|| format!("missing required argument {name}"))
}

fn skip_ws(raw: &str, mut index: usize) -> usize {
    while raw
        .as_bytes()
        .get(index)
        .is_some_and(|byte| byte.is_ascii_whitespace())
    {
        index += 1;
    }
    index
}

fn skip_ws_and_commas(raw: &str, mut index: usize) -> usize {
    while raw
        .as_bytes()
        .get(index)
        .is_some_and(|byte| byte.is_ascii_whitespace() || *byte == b',')
    {
        index += 1;
    }
    index
}

fn json_quote(value: &str) -> String {
    let mut output = String::from("\"");
    for ch in value.chars() {
        match ch {
            '"' => output.push_str("\\\""),
            '\\' => output.push_str("\\\\"),
            '\n' => output.push_str("\\n"),
            '\r' => output.push_str("\\r"),
            '\t' => output.push_str("\\t"),
            other => output.push(other),
        }
    }
    output.push('"');
    output
}

fn now_millis_string() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis().to_string())
        .unwrap_or_else(|_| "0".into())
}

fn emit_receipt(job_id: &str, receipt: &Receipt) {
    let extra = match (receipt.status_code, receipt.response_bytes) {
        (Some(status_code), Some(response_bytes)) => {
            format!(",\"statusCode\":{status_code},\"responseBytes\":{response_bytes}")
        }
        _ => String::new(),
    };
    emit_raw(&format!(
        "{{\"type\":\"receipt\",\"jobId\":{},\"endpointId\":{},\"nodeId\":{},\"channel\":{},\"status\":{},\"bytesSent\":{},\"deliveredAt\":{}{} }}",
        json_quote(job_id),
        json_quote(&receipt.endpoint_id),
        json_quote(&receipt.endpoint_id),
        json_quote(&receipt.channel),
        json_quote(&receipt.status),
        receipt.bytes_sent,
        json_quote(&now_millis_string()),
        extra
    ));
}

fn emit_result(job_id: &str, content_hash: &str, bytes_sent: usize, receipts: &[Receipt]) {
    let receipts_json = receipts
        .iter()
        .map(|receipt| {
            format!(
                "{{\"type\":\"receipt\",\"jobId\":{},\"endpointId\":{},\"nodeId\":{},\"channel\":{},\"status\":{},\"bytesSent\":{},\"deliveredAt\":{}}}",
                json_quote(job_id),
                json_quote(&receipt.endpoint_id),
                json_quote(&receipt.endpoint_id),
                json_quote(&receipt.channel),
                json_quote(&receipt.status),
                receipt.bytes_sent,
                json_quote(&now_millis_string())
            )
        })
        .collect::<Vec<_>>()
        .join(",");
    emit_raw(&format!(
        "{{\"type\":\"result\",\"jobId\":{},\"contentHash\":{},\"bytesSent\":{},\"receipts\":[{}],\"status\":\"sent\",\"at\":{}}}",
        json_quote(job_id),
        json_quote(content_hash),
        bytes_sent,
        receipts_json,
        json_quote(&now_millis_string())
    ));
}

fn emit_error(error: &str) {
    emit_raw(&format!(
        "{{\"type\":\"error\",\"message\":{},\"at\":{}}}",
        json_quote(error),
        json_quote(&now_millis_string())
    ));
}

fn emit_raw(value: &str) {
    record_event_from_raw(value);
    println!("{value}");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decode_base64() {
        let decoded = decode_base64("eyJqb2JJZCI6InRlc3QifQ==").unwrap();
        assert_eq!(String::from_utf8(decoded).unwrap(), "{\"jobId\":\"test\"}");
    }

    #[test]
    fn test_execute_job_payload() {
        let dummy_job = r#"{"jobId":"test-job-1","packet":{"contentHash":"hash123"},"endpoints":[{"transport":"udp","endpointId":"ep1","host":"127.0.0.1","port":9999,"url":"udp://127.0.0.1:9999"}]}"#;
        let res = execute_job_payload(dummy_job);
        assert!(res.is_ok());
        let (bytes, receipts) = res.unwrap();
        assert!(bytes > 0);
        assert_eq!(receipts.len(), 1);
    }

    #[test]
    fn test_daemon_http_server() {
        use std::io::{Read, Write};
        use std::net::TcpStream;
        let port = 18899;
        std::thread::spawn(move || {
            let _ = run_daemon(port);
        });
        std::thread::sleep(std::time::Duration::from_millis(100));

        let mut stream =
            TcpStream::connect(format!("127.0.0.1:{port}")).expect("connect to daemon");
        stream
            .write_all(b"GET /status HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n")
            .expect("write get status");
        let mut resp = [0u8; 1024];
        let n = stream.read(&mut resp).expect("read status response");
        let resp_str = String::from_utf8_lossy(&resp[..n]);
        assert!(resp_str.contains("200 OK"));
        assert!(resp_str.contains("\"daemon\":true"));
    }

    #[test]
    fn test_daemon_job_start_status_stop_in_memory() {
        let job_id = format!("test_daemon_job_{}", now_millis_string());
        let raw_job = format!(
            r#"{{"jobId":"{}","loop":true,"loopIntervalMs":1000,"packet":{{"contentHash":"hash123","loop":true}},"endpoints":[{{"transport":"udp","endpointId":"ep1","host":"127.0.0.1","port":9999}}]}}"#,
            job_id
        );

        let started = start_daemon_job(&raw_job).expect("start daemon job");
        assert!(started.contains("\"storage\":\"memory\""));
        assert!(started.contains("\"persistent\":false"));

        std::thread::sleep(std::time::Duration::from_millis(100));
        let status = daemon_status_json(Some(&job_id), 0, 20);
        assert!(status.contains(&job_id));
        assert!(status.contains("\"source\":\"rust-daemon-master\""));

        let stopped = stop_daemon_job(Some(&job_id)).expect("stop daemon job");
        assert!(stopped.contains("\"ok\":true"));
    }
}
