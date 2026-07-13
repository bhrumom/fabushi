use serde_json::Value;
use std::{
    fs,
    io::Write,
    process::{Command, Stdio},
    time::{SystemTime, UNIX_EPOCH},
};

fn mahayana() -> Command {
    Command::new(env!("CARGO_BIN_EXE_mahayana"))
}

#[test]
fn status_reports_the_shared_rust_kernel() {
    let output = mahayana().arg("status").output().unwrap();
    assert!(output.status.success());
    let status: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(status["core"], "codex-rust-sdk");
    assert_eq!(status["codexDriver"], "codex-client-sdk");
    assert_eq!(status["codexDistribution"], "bundled");
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
    assert!(tools
        .iter()
        .any(|tool| tool["name"] == "mahayana.codex.run"));
}

#[cfg(unix)]
#[test]
fn agent_command_uses_the_rust_sdk_transport() {
    use std::os::unix::fs::PermissionsExt;

    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let script = std::env::temp_dir().join(format!("mahayana-cli-fake-codex-{nonce}.sh"));
    fs::write(
        &script,
        "#!/bin/sh\ncase \"$*\" in\n  *\"exec --experimental-json\"*) ;;\n  *) exit 64 ;;\nesac\ncat >/dev/null\nprintf '%s\\n' '{\"type\":\"thread.started\",\"thread_id\":\"cli-sdk-thread\"}' '{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"id\":\"message-1\",\"text\":\"CLI SDK response\"}}' '{\"type\":\"turn.completed\",\"usage\":{\"input_tokens\":1,\"cached_input_tokens\":0,\"output_tokens\":2}}'\n",
    )
    .unwrap();
    fs::set_permissions(&script, fs::Permissions::from_mode(0o700)).unwrap();
    let output = mahayana()
        .env("MAHAYANA_CODEX_BIN", &script)
        .args(["agent", "return", "a", "test", "response"])
        .output()
        .unwrap();
    fs::remove_file(script).unwrap();
    assert!(output.status.success());
    let response: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(response["driver"], "codex-client-sdk");
    assert_eq!(response["threadId"], "cli-sdk-thread");
    assert_eq!(response["finalResponse"], "CLI SDK response");
}

#[cfg(unix)]
#[test]
fn mcp_codex_tool_uses_the_same_rust_sdk_transport() {
    use std::os::unix::fs::PermissionsExt;

    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let script = std::env::temp_dir().join(format!("mahayana-mcp-fake-codex-{nonce}.sh"));
    fs::write(
        &script,
        "#!/bin/sh\ncase \"$*\" in\n  *\"exec --experimental-json\"*) ;;\n  *) exit 64 ;;\nesac\ncat >/dev/null\nprintf '%s\\n' '{\"type\":\"thread.started\",\"thread_id\":\"mcp-sdk-thread\"}' '{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"id\":\"message-1\",\"text\":\"MCP SDK response\"}}' '{\"type\":\"turn.completed\",\"usage\":{\"input_tokens\":1,\"cached_input_tokens\":0,\"output_tokens\":2}}'\n",
    )
    .unwrap();
    fs::set_permissions(&script, fs::Permissions::from_mode(0o700)).unwrap();
    let mut child = mahayana()
        .env("MAHAYANA_CODEX_BIN", &script)
        .arg("mcp-server")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    writeln!(
        stdin,
        r#"{{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{{"name":"mahayana.codex.run","arguments":{{"prompt":"return an answer","confirmed":true}}}}}}"#
    )
    .unwrap();
    drop(stdin);
    let output = child.wait_with_output().unwrap();
    fs::remove_file(script).unwrap();
    assert!(output.status.success());
    let response: Value = serde_json::from_slice(&output.stdout).unwrap();
    let text = response["result"]["content"][0]["text"].as_str().unwrap();
    assert!(text.contains("MCP SDK response"));
    assert!(text.contains("mcp-sdk-thread"));
}

#[cfg(unix)]
#[test]
fn login_uses_the_codex_binary_shipped_with_mahayana() {
    use std::os::unix::fs::PermissionsExt;

    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::env::temp_dir().join(format!("mahayana-bundle-{nonce}"));
    let bin_dir = root.join("bin");
    let lib_dir = root.join("lib/mahayana");
    fs::create_dir_all(&bin_dir).unwrap();
    fs::create_dir_all(&lib_dir).unwrap();
    let bundled_mahayana = bin_dir.join("mahayana");
    fs::copy(env!("CARGO_BIN_EXE_mahayana"), &bundled_mahayana).unwrap();
    fs::set_permissions(&bundled_mahayana, fs::Permissions::from_mode(0o700)).unwrap();
    let bundled_codex = lib_dir.join("codex");
    fs::write(
        &bundled_codex,
        "#!/bin/sh\n[ \"$1\" = login ] || exit 64\nprintf '%s\\n' 'bundled Codex login'\n",
    )
    .unwrap();
    fs::set_permissions(&bundled_codex, fs::Permissions::from_mode(0o700)).unwrap();
    let output = Command::new(&bundled_mahayana)
        .arg("login")
        .output()
        .unwrap();
    fs::remove_dir_all(root).unwrap();
    assert!(output.status.success());
    assert_eq!(
        String::from_utf8(output.stdout).unwrap(),
        "bundled Codex login\n"
    );
}
