use fabushi_messaging_core::{CallSignalingServerConfig, CallSignalingTcpServer};
use std::env;

fn main() {
    if let Err(error) = run() {
        eprintln!("Fabushi call signaling server failed: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let bind = env::var("FABUSHI_CALL_SIGNAL_BIND").unwrap_or_else(|_| "127.0.0.1:9410".into());
    let token = env::var("FABUSHI_CALL_SIGNAL_ACCESS_TOKEN").map_err(|_| {
        "FABUSHI_CALL_SIGNAL_ACCESS_TOKEN is required and must contain at least 32 bytes"
    })?;
    let config = CallSignalingServerConfig::new(bind, token);
    let server = CallSignalingTcpServer::new(config)?;
    server.serve()?;
    Ok(())
}
