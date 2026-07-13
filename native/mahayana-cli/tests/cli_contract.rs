use serde_json::Value;
use std::{
    io::Write,
    process::{Command, Stdio},
};

fn mahayana() -> Command {
    Command::new(env!("CARGO_BIN_EXE_mahayana"))
}

#[test]
fn status_reports_the_shared_rust_kernel() {
    let output = mahayana().arg("status").output().unwrap();
    assert!(output.status.success());
    let status: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(status["core"], "upstream-codex-cli");
    assert!(status["sharedRustModules"]
        .as_array()
        .unwrap()
        .iter()
        .any(|value| value == "fabushi-miniapp-runtime"));
}

#[test]
fn cli_accepts_the_checked_in_global_dharma_web_manifest() {
    let manifest = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(
        "../../frontend/apps/web/public/miniapps/official.global-dharma/runtime/manifest.json",
    );
    let output = mahayana()
        .args(["miniapp", "inspect", manifest.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(output.status.success());
    let inspection: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(inspection["id"], "official.global-dharma");
    assert_eq!(inspection["valid"], true);
    assert_eq!(inspection["unknownPermissions"], serde_json::json!([]));
}

#[test]
fn mcp_server_advertises_telegram_and_web_miniapp_tools() {
    let mut child = mahayana()
        .arg("mcp-server")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    writeln!(stdin, r#"{{"jsonrpc":"2.0","id":1,"method":"tools/list"}}"#).unwrap();
    drop(stdin);
    let output = child.wait_with_output().unwrap();
    assert!(output.status.success());
    let response: Value = serde_json::from_slice(&output.stdout).unwrap();
    let tools = response["result"]["tools"].as_array().unwrap();
    assert!(tools
        .iter()
        .any(|tool| tool["name"] == "mahayana.telegram.execute"));
    assert!(tools
        .iter()
        .any(|tool| tool["name"] == "mahayana.miniapp.inspect"));
}
