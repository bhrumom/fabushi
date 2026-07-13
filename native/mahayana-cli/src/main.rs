use mahayana_wrapper::MahayanaKernel;
use serde_json::{json, Map, Value};
use std::{
    env,
    io::{self, BufRead, Write},
    process::{Command, ExitCode},
};

fn main() -> ExitCode {
    match run(env::args().skip(1).collect()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("mahayana: {error}");
            ExitCode::from(1)
        }
    }
}

fn run(args: Vec<String>) -> Result<(), String> {
    let kernel = MahayanaKernel::default();
    match args.first().map(String::as_str) {
        None | Some("help") | Some("--help") | Some("-h") => {
            print_usage();
            Ok(())
        }
        Some("status") => {
            println!("{}", kernel.status());
            Ok(())
        }
        Some("codex") => run_upstream_codex(&kernel, &args[1..]),
        Some("mcp-server") => run_mcp_server(&kernel),
        Some("mcp") => run_mcp_command(&kernel, &args[1..]),
        Some("telegram") => run_telegram_command(&kernel, &args[1..]),
        Some("miniapp") => run_miniapp_command(&kernel, &args[1..]),
        Some(other) => Err(format!("unknown command {other}; run `mahayana help`")),
    }
}

/// Runs the installed upstream executable without changing its arguments or
/// identity.  `MAHAYANA_CODEX_BIN` allows the app bundle to point at its
/// packaged Codex binary, while developers can upgrade that binary normally.
fn run_upstream_codex(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    let status = Command::new(kernel.upstream_codex_binary())
        .args(args)
        .status()
        .map_err(|error| {
            format!(
                "could not start upstream Codex at {}: {error}",
                kernel.upstream_codex_binary().display()
            )
        })?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("upstream Codex exited with {status}"))
    }
}

fn run_mcp_command(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        Some("serve") => run_mcp_server(kernel),
        Some("install") => install_mcp_server(kernel),
        Some("install-global-dharma") => install_global_dharma_mcp(kernel),
        Some("print-install") => {
            let current = env::current_exe().map_err(|error| error.to_string())?;
            println!(
                "{} mcp add mahayana -- {} mcp-server",
                kernel.upstream_codex_binary().display(),
                current.display()
            );
            Ok(())
        }
        _ => {
            Err("usage: mahayana mcp serve|install|install-global-dharma|print-install".to_string())
        }
    }
}

/// Registers the bundled stdio service using Codex's own `mcp add` command.
/// This is intentionally an explicit command: merely running Mahayana never
/// edits the user's upstream Codex configuration.
fn install_mcp_server(kernel: &MahayanaKernel) -> Result<(), String> {
    let current = env::current_exe().map_err(|error| error.to_string())?;
    let status = Command::new(kernel.upstream_codex_binary())
        .args(["mcp", "add", "mahayana", "--"])
        .arg(current)
        .arg("mcp-server")
        .status()
        .map_err(|error| format!("could not register Mahayana MCP server: {error}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("Codex MCP registration exited with {status}"))
    }
}

fn install_global_dharma_mcp(kernel: &MahayanaKernel) -> Result<(), String> {
    let server =
        env::var("GLOBAL_DHARMA_MCP_BIN").unwrap_or_else(|_| "global-dharma-mcp".to_string());
    let status = Command::new(kernel.upstream_codex_binary())
        .args(["mcp", "add", "global-dharma", "--", &server])
        .status()
        .map_err(|error| format!("could not register Global Dharma MCP server: {error}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!(
            "Global Dharma MCP registration exited with {status}"
        ))
    }
}

fn run_telegram_command(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        Some("status") => {
            let client_id = create_telegram_client(kernel)?;
            let response = kernel.execute(json!({
                "@type": "mahayana.telegram.execute",
                "clientId": client_id,
                "request": {"@type": "telegram.getStatus"},
            }));
            let _ = kernel.execute(json!({
                "@type": "mahayana.telegram.closeClient",
                "clientId": client_id,
            }));
            println!("{}", response.map_err(|error| error.to_string())?);
            Ok(())
        }
        Some("request") => {
            let source = args
                .get(1)
                .ok_or_else(|| "usage: mahayana telegram request '<json>'".to_string())?;
            let request = parse_object(source, "Telegram request")?;
            let client_id = create_telegram_client(kernel)?;
            let response = kernel.execute(json!({
                "@type": "mahayana.telegram.execute",
                "clientId": client_id,
                "request": request,
            }));
            let _ = kernel.execute(json!({
                "@type": "mahayana.telegram.closeClient",
                "clientId": client_id,
            }));
            println!("{}", response.map_err(|error| error.to_string())?);
            Ok(())
        }
        _ => Err("usage: mahayana telegram status|request '<json>'".to_string()),
    }
}

fn create_telegram_client(kernel: &MahayanaKernel) -> Result<u64, String> {
    kernel
        .execute(json!({"@type": "mahayana.telegram.createClient"}))
        .map_err(|error| error.to_string())?
        .get("clientId")
        .and_then(Value::as_u64)
        .ok_or_else(|| "Mahayana kernel did not return a Telegram client id".to_string())
}

fn run_miniapp_command(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        Some("inspect") => {
            let manifest_path = args
                .get(1)
                .ok_or_else(|| "usage: mahayana miniapp inspect <manifest.json>".to_string())?;
            let response = kernel
                .execute(json!({
                    "@type": "mahayana.miniapp.inspect",
                    "manifestPath": manifest_path,
                }))
                .map_err(|error| error.to_string())?;
            println!("{response}");
            Ok(())
        }
        Some("evaluate") => {
            let method = args.get(1).ok_or_else(|| {
                "usage: mahayana miniapp evaluate <method> [permission,...] [platform]".to_string()
            })?;
            let permissions = args
                .get(2)
                .map(|source| {
                    source
                        .split(',')
                        .map(str::trim)
                        .filter(|item| !item.is_empty())
                        .collect::<Vec<_>>()
                })
                .unwrap_or_default();
            let platform = args.get(3).map(String::as_str).unwrap_or("unknown");
            let response = kernel
                .execute(json!({
                    "@type": "mahayana.miniapp.evaluate",
                    "method": method,
                    "declaredPermissions": permissions,
                    "platform": platform,
                    "trustedOfficial": true,
                }))
                .map_err(|error| error.to_string())?;
            println!("{response}");
            Ok(())
        }
        Some("request") => {
            let source = args
                .get(1)
                .ok_or_else(|| "usage: mahayana miniapp request '<json>'".to_string())?;
            let request = parse_object(source, "mini-app request")?;
            let response = kernel
                .execute(json!({
                    "@type": "mahayana.miniapp.execute",
                    "request": request,
                }))
                .map_err(|error| error.to_string())?;
            println!("{response}");
            Ok(())
        }
        _ => Err("usage: mahayana miniapp inspect|evaluate|request".to_string()),
    }
}

fn run_mcp_server(kernel: &MahayanaKernel) -> Result<(), String> {
    let stdout = io::stdout();
    let mut stdout = stdout.lock();
    for line in io::stdin().lock().lines() {
        let line = line.map_err(|error| error.to_string())?;
        if line.trim().is_empty() {
            continue;
        }
        let request = match serde_json::from_str::<Value>(&line) {
            Ok(request) => request,
            Err(error) => {
                write_jsonrpc_error(
                    &mut stdout,
                    Value::Null,
                    -32700,
                    &format!("parse error: {error}"),
                )?;
                continue;
            }
        };
        let id = request.get("id").cloned();
        let result = handle_mcp_request(kernel, &request);
        if let Some(id) = id {
            match result {
                Ok(result) => write_jsonrpc_result(&mut stdout, id, result)?,
                Err(error) => write_jsonrpc_error(&mut stdout, id, -32000, &error)?,
            }
        }
    }
    Ok(())
}

fn handle_mcp_request(kernel: &MahayanaKernel, request: &Value) -> Result<Value, String> {
    let method = request
        .get("method")
        .and_then(Value::as_str)
        .ok_or_else(|| "JSON-RPC request is missing method".to_string())?;
    match method {
        "initialize" => Ok(json!({
            "protocolVersion": request.pointer("/params/protocolVersion").and_then(Value::as_str).unwrap_or("2025-03-26"),
            "capabilities": {"tools": {"listChanged": false}},
            "serverInfo": {"name": "mahayana", "version": env!("CARGO_PKG_VERSION")},
        })),
        "tools/list" => Ok(json!({"tools": mcp_tools()})),
        "tools/call" => call_mcp_tool(kernel, request.pointer("/params")),
        "notifications/initialized" => Ok(json!({})),
        other => Err(format!("unsupported MCP method: {other}")),
    }
}

fn call_mcp_tool(kernel: &MahayanaKernel, params: Option<&Value>) -> Result<Value, String> {
    let params = params
        .and_then(Value::as_object)
        .ok_or_else(|| "tools/call requires params".to_string())?;
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .ok_or_else(|| "tools/call requires params.name".to_string())?;
    let arguments = params
        .get("arguments")
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();

    let (kernel_type, requires_confirmation) = match name {
        "mahayana.status" => ("mahayana.status", false),
        "mahayana.telegram.create_client" => ("mahayana.telegram.createClient", false),
        "mahayana.telegram.execute" => ("mahayana.telegram.execute", true),
        "mahayana.miniapp.inspect" => ("mahayana.miniapp.inspect", false),
        "mahayana.miniapp.evaluate" => ("mahayana.miniapp.evaluate", false),
        "mahayana.miniapp.execute" => ("mahayana.miniapp.execute", true),
        _ => return Err(format!("unknown Mahayana tool: {name}")),
    };

    if requires_confirmation && arguments.get("confirmed").and_then(Value::as_bool) != Some(true) {
        return Ok(json!({
            "content": [{"type": "text", "text": format!("{name}: explicit confirmation is required before execution")}],
            "isError": true,
        }));
    }

    let mut request = Map::new();
    request.insert("@type".to_string(), Value::String(kernel_type.to_string()));
    request.extend(arguments);
    request.remove("confirmed");
    let result = kernel
        .execute(Value::Object(request))
        .map_err(|error| error.to_string())?;
    Ok(json!({
        "content": [{"type": "text", "text": result.to_string()}],
    }))
}

fn mcp_tools() -> Vec<Value> {
    vec![
        mcp_tool("mahayana.status", "Show the active shared Rust kernel and upstream Codex path.", json!({"type":"object","properties":{}}), true),
        mcp_tool("mahayana.telegram.create_client", "Create an in-process Rust Telegram client for subsequent tool calls.", json!({"type":"object","properties":{}}), false),
        mcp_tool("mahayana.telegram.execute", "Execute a Telegram Rust runtime request. Networked/authentication actions require confirmation.", json!({"type":"object","properties":{"clientId":{"type":"integer","minimum":1},"request":{"type":"object"},"confirmed":{"type":"boolean"}},"required":["clientId","request","confirmed"]}), false),
        mcp_tool("mahayana.miniapp.inspect", "Inspect a web mini-app manifest against the shared Rust capability registry.", json!({"type":"object","properties":{"manifestPath":{"type":"string"}},"required":["manifestPath"]}), true),
        mcp_tool("mahayana.miniapp.evaluate", "Evaluate a mini-app host-method permission without invoking the method.", json!({"type":"object","properties":{"method":{"type":"string"},"declaredPermissions":{"type":"array","items":{"type":"string"}},"platform":{"type":"string"},"trustedOfficial":{"type":"boolean"}},"required":["method"]}), true),
        mcp_tool("mahayana.miniapp.execute", "Execute an approved Rust mini-app host request. Network and mutation requests require confirmation.", json!({"type":"object","properties":{"request":{"type":"object"},"confirmed":{"type":"boolean"}},"required":["request","confirmed"]}), false),
    ]
}

fn mcp_tool(name: &str, description: &str, input_schema: Value, read_only: bool) -> Value {
    json!({
        "name": name,
        "description": description,
        "inputSchema": input_schema,
        "annotations": {"readOnlyHint": read_only},
    })
}

fn write_jsonrpc_result(stdout: &mut impl Write, id: Value, result: Value) -> Result<(), String> {
    writeln!(
        stdout,
        "{}",
        json!({"jsonrpc": "2.0", "id": id, "result": result})
    )
    .map_err(|error| error.to_string())?;
    stdout.flush().map_err(|error| error.to_string())
}

fn write_jsonrpc_error(
    stdout: &mut impl Write,
    id: Value,
    code: i64,
    message: &str,
) -> Result<(), String> {
    writeln!(
        stdout,
        "{}",
        json!({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})
    )
    .map_err(|error| error.to_string())?;
    stdout.flush().map_err(|error| error.to_string())
}

fn parse_object(source: &str, label: &str) -> Result<Value, String> {
    serde_json::from_str::<Value>(source)
        .map_err(|error| format!("{label} must be valid JSON: {error}"))
        .and_then(|value| {
            if value.is_object() {
                Ok(value)
            } else {
                Err(format!("{label} must be a JSON object"))
            }
        })
}

fn print_usage() {
    println!(
        "Mahayana CLI\n\n\
         mahayana status\n\
         mahayana codex [UPSTREAM_CODEX_ARGS...]\n\
         mahayana mcp serve|install|install-global-dharma|print-install\n\
         mahayana telegram status|request '<json>'\n\
         mahayana miniapp inspect <manifest.json>\n\
         mahayana miniapp evaluate <method> [permission,...] [platform]\n\
         mahayana miniapp request '<json>'\n\n\
         Set MAHAYANA_CODEX_BIN to select the bundled/upgraded upstream Codex executable."
    );
}
