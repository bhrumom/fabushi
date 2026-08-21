use crate::protocol::{ClientEnvelope, ServerEnvelope};
use crate::service::{MessagingService, MessagingServiceError};
use crate::store::JsonFileStateStore;
use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH};
use thiserror::Error;

pub const MAX_SERVER_FRAME_BYTES: usize = 8 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AuthenticatedClientFrame {
    pub access_token: String,
    pub envelope: ClientEnvelope,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", rename_all_fields = "camelCase", tag = "type")]
pub enum ServerFrame {
    Events { events: Vec<ServerEnvelope> },
    Error { code: String, message: String },
}

#[derive(Debug, Clone)]
pub struct MessagingServerConfig {
    pub bind_address: String,
    pub snapshot_path: PathBuf,
    pub access_token: String,
    pub max_frame_bytes: usize,
}

impl MessagingServerConfig {
    pub fn new(
        bind_address: impl Into<String>,
        snapshot_path: impl Into<PathBuf>,
        access_token: impl Into<String>,
    ) -> Self {
        Self {
            bind_address: bind_address.into(),
            snapshot_path: snapshot_path.into(),
            access_token: access_token.into(),
            max_frame_bytes: MAX_SERVER_FRAME_BYTES,
        }
    }

    pub fn validate(&self) -> Result<(), MessagingServerError> {
        if self.bind_address.trim().is_empty() {
            return Err(MessagingServerError::InvalidConfig(
                "bind address is empty".into(),
            ));
        }
        if self.access_token.len() < 32 {
            return Err(MessagingServerError::InvalidConfig(
                "access token must contain at least 32 bytes".into(),
            ));
        }
        if self.max_frame_bytes < 1024 {
            return Err(MessagingServerError::InvalidConfig(
                "maximum frame size is too small".into(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Error)]
pub enum MessagingServerError {
    #[error("messaging server configuration is invalid: {0}")]
    InvalidConfig(String),
    #[error("messaging server I/O failed: {0}")]
    Io(#[from] std::io::Error),
    #[error("messaging server JSON failed: {0}")]
    Json(#[from] serde_json::Error),
    #[error("messaging service failed: {0}")]
    Service(#[from] MessagingServiceError),
    #[error("messaging service lock is poisoned")]
    Poisoned,
}

pub struct MessagingTcpServer {
    config: MessagingServerConfig,
    service: Arc<Mutex<MessagingService<JsonFileStateStore>>>,
}

impl MessagingTcpServer {
    pub fn load(config: MessagingServerConfig) -> Result<Self, MessagingServerError> {
        config.validate()?;
        let store = JsonFileStateStore::new(config.snapshot_path.clone());
        let service = MessagingService::load(store)?;
        Ok(Self {
            config,
            service: Arc::new(Mutex::new(service)),
        })
    }

    pub fn snapshot_path(&self) -> &Path {
        &self.config.snapshot_path
    }

    pub fn serve(self) -> Result<(), MessagingServerError> {
        let listener = TcpListener::bind(&self.config.bind_address)?;
        let token = Arc::new(self.config.access_token);
        let max_frame_bytes = self.config.max_frame_bytes;
        for incoming in listener.incoming() {
            let stream = match incoming {
                Ok(stream) => stream,
                Err(error) => {
                    eprintln!("Fabushi messaging accept failed: {error}");
                    continue;
                }
            };
            let service = Arc::clone(&self.service);
            let token = Arc::clone(&token);
            thread::spawn(move || {
                if let Err(error) = handle_connection(
                    stream,
                    service,
                    token.as_str(),
                    max_frame_bytes,
                ) {
                    eprintln!("Fabushi messaging connection failed: {error}");
                }
            });
        }
        Ok(())
    }
}

fn handle_connection(
    stream: TcpStream,
    service: Arc<Mutex<MessagingService<JsonFileStateStore>>>,
    access_token: &str,
    max_frame_bytes: usize,
) -> Result<(), MessagingServerError> {
    stream.set_nodelay(true)?;
    let reader_stream = stream.try_clone()?;
    let mut reader = BufReader::new(reader_stream);
    let mut writer = BufWriter::new(stream);
    let mut line = Vec::new();

    loop {
        line.clear();
        let read = reader.read_until(b'\n', &mut line)?;
        if read == 0 {
            break;
        }
        if line.len() > max_frame_bytes {
            write_frame(
                &mut writer,
                &ServerFrame::Error {
                    code: "frame_too_large".into(),
                    message: format!("frame exceeds {max_frame_bytes} bytes"),
                },
            )?;
            break;
        }
        while matches!(line.last(), Some(b'\n' | b'\r')) {
            line.pop();
        }
        if line.is_empty() {
            continue;
        }
        let request: AuthenticatedClientFrame = match serde_json::from_slice(&line) {
            Ok(request) => request,
            Err(error) => {
                write_frame(
                    &mut writer,
                    &ServerFrame::Error {
                        code: "invalid_json".into(),
                        message: error.to_string(),
                    },
                )?;
                continue;
            }
        };
        if !constant_time_eq(request.access_token.as_bytes(), access_token.as_bytes()) {
            write_frame(
                &mut writer,
                &ServerFrame::Error {
                    code: "unauthorized".into(),
                    message: "access token is invalid".into(),
                },
            )?;
            continue;
        }
        let now_ms = now_millis();
        let events = {
            let mut service = service.lock().map_err(|_| MessagingServerError::Poisoned)?;
            match service.handle(request.envelope, now_ms) {
                Ok(events) => events,
                Err(error) => {
                    write_frame(
                        &mut writer,
                        &ServerFrame::Error {
                            code: "messaging_error".into(),
                            message: error.to_string(),
                        },
                    )?;
                    continue;
                }
            }
        };
        write_frame(&mut writer, &ServerFrame::Events { events })?;
    }
    Ok(())
}

fn write_frame(
    writer: &mut BufWriter<TcpStream>,
    frame: &ServerFrame,
) -> Result<(), MessagingServerError> {
    serde_json::to_writer(&mut *writer, frame)?;
    writer.write_all(b"\n")?;
    writer.flush()?;
    Ok(())
}

fn now_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis().min(i64::MAX as u128) as i64)
        .unwrap_or_default()
}

fn constant_time_eq(left: &[u8], right: &[u8]) -> bool {
    if left.len() != right.len() {
        return false;
    }
    let mut difference = 0u8;
    for (left, right) in left.iter().zip(right) {
        difference |= left ^ right;
    }
    difference == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn token_comparison_requires_equal_contents_and_length() {
        assert!(constant_time_eq(b"same", b"same"));
        assert!(!constant_time_eq(b"same", b"diff"));
        assert!(!constant_time_eq(b"short", b"longer"));
    }

    #[test]
    fn production_config_rejects_short_tokens() {
        let config = MessagingServerConfig::new("127.0.0.1:9400", "/tmp/messages.json", "short");
        assert!(config.validate().is_err());
    }
}
