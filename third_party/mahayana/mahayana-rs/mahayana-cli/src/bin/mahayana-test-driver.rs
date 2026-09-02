#[cfg(not(debug_assertions))]
compile_error!(
    "mahayana-test-driver is forbidden in release builds; use a Debug/test-signed build"
);

#[cfg(not(debug_assertions))]
fn main() {}

#[cfg(debug_assertions)]
use mahayana_test_driver_protocol::{
    TestDriverBackend, TestDriverError, TestDriverMethod, TestDriverSession,
};
#[cfg(debug_assertions)]
use serde_json::Value;
#[cfg(debug_assertions)]
use std::io::{self, BufRead, Write};

#[cfg(debug_assertions)]
struct ControlPlaneBackend;

#[cfg(debug_assertions)]
impl TestDriverBackend for ControlPlaneBackend {
    fn backend_name(&self) -> &'static str {
        "mahayana-control-plane-round1"
    }

    fn execute(
        &mut self,
        method: TestDriverMethod,
        _params: Value,
        _correlation_id: &str,
    ) -> Result<Value, TestDriverError> {
        Err(TestDriverError::new(
            "product_backend_not_wired",
            format!(
                "{} requires the Mahayana product-core adapter; the protocol/control-plane slice is active",
                method.as_str()
            ),
        ))
    }
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
    let mut session = TestDriverSession::new(ControlPlaneBackend);

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
