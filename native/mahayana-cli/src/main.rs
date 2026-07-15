use mahayana_wrapper::{redact_secrets, MahayanaKernel};
use serde_json::{json, Map, Value};
use std::{
    env,
    io::{self, BufRead, Write},
    process::{Command, ExitCode},
    thread,
    time::Duration,
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
        None => launch_tui(&kernel, &[]),
        Some("help") | Some("--help") | Some("-h") => {
            print_usage();
            Ok(())
        }
        Some("tui") | Some("chat") => launch_tui(&kernel, &args[1..]),
        Some("status") => {
            println!("{}", kernel.status());
            Ok(())
        }
        Some("agent") | Some("codex") => run_agent(&kernel, &args[1..]),
        Some("codex-login") | Some("codex-logout") | Some("doctor") => {
            let command = match args[0].as_str() {
                "codex-login" => "login",
                "codex-logout" => "logout",
                other => other,
            };
            run_bundled_codex_management(&kernel, command, &args[1..])
        }
        Some("login") => run_login_command(&kernel, &args[1..]),
        Some("logout") => print_kernel_response(&kernel, json!({"@type":"mahayana.auth.logout"})),
        Some("auth") => run_auth_command(&kernel, &args[1..]),
        Some("contacts") | Some("contact") | Some("friends") => {
            run_contacts_command(&kernel, &args[1..])
        }
        Some("messages") | Some("message") => run_messages_command(&kernel, &args[1..]),
        Some("request") => run_kernel_request(&kernel, &args[1..]),
        Some("mcp-server") => run_mcp_server(&kernel),
        Some("mcp") => run_mcp_command(&kernel, &args[1..]),
        Some("telegram") => run_telegram_command(&kernel, &args[1..]),
        Some("miniapp") => run_miniapp_command(&kernel, &args[1..]),
        Some(other) => Err(format!("unknown command {other}; run `mahayana help`")),
    }
}

/// Launches the Codex TUI shipped with Mahayana and injects this executable as
/// a stdio MCP server for this process. It does not mutate the user's global
/// Codex config, so `mahayana` is immediately useful after installation.
fn launch_tui(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    let current = env::current_exe().map_err(|error| error.to_string())?;
    let command = serde_json::to_string(&current.to_string_lossy().as_ref())
        .map_err(|error| error.to_string())?;
    let instructions = serde_json::to_string(
        "你是大乘 CLI 的对话助手。登录、联系人、好友、私信和小程序操作必须优先使用 mahayana MCP 工具；不要要求用户手工调用底层 HTTP API。支付宝登录先调用 alipay_start 打开授权，再用返回的 state 调用 alipay_poll，直到完成。写操作先向用户确认。普通对话与软件开发能力继续使用 Codex。",
    )
    .map_err(|error| error.to_string())?;
    let status = Command::new(kernel.upstream_codex_binary())
        .args(["-c", &format!("mcp_servers.mahayana.command={command}")])
        .args(["-c", "mcp_servers.mahayana.args=[\"mcp-server\"]"])
        .args(["-c", &format!("developer_instructions={instructions}")])
        .args(args)
        .status()
        .map_err(|error| {
            format!(
                "could not start bundled Codex TUI at {}: {error}",
                kernel.upstream_codex_binary().display()
            )
        })?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("bundled Codex TUI exited with {status}"))
    }
}

fn print_kernel_response(kernel: &MahayanaKernel, request: Value) -> Result<(), String> {
    let response = kernel.execute(request).map_err(|error| error.to_string())?;
    println!("{}", redact_secrets(&response));
    Ok(())
}

fn run_kernel_request(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    let source = args
        .first()
        .ok_or_else(|| "usage: mahayana request '<json>'".to_string())?;
    print_kernel_response(kernel, parse_object(source, "Mahayana request")?)
}

fn run_login_command(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        Some("complete") => {
            let auth_code = args
                .get(1)
                .ok_or_else(|| "usage: mahayana login complete <auth-code> [state]".to_string())?;
            print_kernel_response(
                kernel,
                json!({
                    "@type": "mahayana.auth.alipay.complete",
                    "authCode": auth_code,
                    "state": args.get(2),
                }),
            )
        }
        None | Some("start") => {
            let response = kernel
                .execute(json!({
                    "@type": "mahayana.auth.alipay.start",
                    "platform": "cli",
                }))
                .map_err(|error| error.to_string())?;
            if let Some(login_url) = response.get("loginUrl").and_then(Value::as_str) {
                if open_browser(login_url).is_err() {
                    eprintln!("请在浏览器打开支付宝授权地址：{login_url}");
                } else {
                    eprintln!("已打开支付宝授权页面，正在等待授权结果…");
                }
            }
            let state = response
                .get("state")
                .and_then(Value::as_str)
                .ok_or_else(|| "支付宝登录接口没有返回 state".to_string())?;
            wait_for_alipay_login(kernel, state)
        }
        Some(other) => Err(format!(
            "unknown login action {other}; use `mahayana login` or `mahayana login complete <auth-code> [state]`"
        )),
    }
}

fn wait_for_alipay_login(kernel: &MahayanaKernel, state: &str) -> Result<(), String> {
    for _ in 0..150 {
        let response = kernel.execute(json!({
            "@type": "mahayana.auth.alipay.poll",
            "state": state,
        }));
        match response {
            Ok(response) if response.get("status").and_then(Value::as_str) == Some("complete") => {
                println!("{}", redact_secrets(&response));
                eprintln!("大乘软件账号登录成功。");
                return Ok(());
            }
            Ok(response) if response.get("status").and_then(Value::as_str) == Some("pending") => {}
            Ok(response) => {
                return Err(response
                    .get("error")
                    .and_then(Value::as_str)
                    .unwrap_or("支付宝登录未完成")
                    .to_string())
            }
            Err(error) => return Err(error.to_string()),
        }
        thread::sleep(Duration::from_secs(2));
    }
    Err("等待支付宝授权超时，请重新运行 `mahayana login`".to_string())
}

fn run_auth_command(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        None | Some("status") => {
            print_kernel_response(kernel, json!({"@type":"mahayana.auth.status"}))
        }
        Some("login") => run_login_command(kernel, &args[1..]),
        Some("logout") => print_kernel_response(kernel, json!({"@type":"mahayana.auth.logout"})),
        _ => Err("usage: mahayana auth status|login|logout".to_string()),
    }
}

fn run_contacts_command(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        None | Some("list") => {
            print_kernel_response(kernel, json!({"@type":"mahayana.contacts.list"}))
        }
        Some("search") => {
            let query = args.get(1).ok_or_else(|| {
                "usage: mahayana contacts search <name|username|user-no>".to_string()
            })?;
            print_kernel_response(
                kernel,
                json!({"@type":"mahayana.contacts.search", "query": query}),
            )
        }
        Some("add") => {
            let contact = args.get(1).ok_or_else(|| {
                "usage: mahayana contacts add <user-id|username> [message]".to_string()
            })?;
            print_kernel_response(
                kernel,
                json!({
                    "@type":"mahayana.contacts.add",
                    "contact":contact,
                    "message":args.get(2..).unwrap_or_default().join(" "),
                }),
            )
        }
        Some("requests") => {
            print_kernel_response(kernel, json!({"@type":"mahayana.contacts.requests"}))
        }
        Some("accept") => {
            let request_id = args
                .get(1)
                .ok_or_else(|| "usage: mahayana contacts accept <request-id>".to_string())?;
            print_kernel_response(
                kernel,
                json!({"@type":"mahayana.contacts.accept", "requestId":request_id}),
            )
        }
        _ => Err("usage: mahayana contacts list|search|add|requests|accept".to_string()),
    }
}

fn run_messages_command(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        Some("list") => {
            let contact = args.get(1).ok_or_else(|| {
                "usage: mahayana messages list <user-id|username> [limit]".to_string()
            })?;
            let limit = args
                .get(2)
                .and_then(|value| value.parse::<u64>().ok())
                .unwrap_or(50);
            print_kernel_response(
                kernel,
                json!({"@type":"mahayana.messages.list", "contact":contact, "limit":limit}),
            )
        }
        Some("send") => {
            let contact = args.get(1).ok_or_else(|| {
                "usage: mahayana messages send <user-id|username> <text>".to_string()
            })?;
            let text = args.get(2..).unwrap_or_default().join(" ");
            if text.trim().is_empty() {
                return Err("usage: mahayana messages send <user-id|username> <text>".to_string());
            }
            print_kernel_response(
                kernel,
                json!({"@type":"mahayana.messages.send", "contact":contact, "text":text}),
            )
        }
        _ => Err("usage: mahayana messages list|send".to_string()),
    }
}

fn open_browser(url: &str) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    let status = Command::new("open").arg(url).status();
    #[cfg(target_os = "linux")]
    let status = Command::new("xdg-open").arg(url).status();
    #[cfg(target_os = "windows")]
    let status = Command::new("cmd").args(["/C", "start", "", url]).status();
    #[cfg(not(any(target_os = "macos", target_os = "linux", target_os = "windows")))]
    return Err("automatic browser opening is unavailable on this platform".to_string());
    status
        .map_err(|error| error.to_string())
        .and_then(|status| {
            status
                .success()
                .then_some(())
                .ok_or_else(|| status.to_string())
        })
}

/// Authentication and diagnostics are product-management commands provided by
/// the Codex executable shipped inside the Mahayana installation. Agent turns
/// continue to use the Rust SDK path in `run_agent`.
fn run_bundled_codex_management(
    kernel: &MahayanaKernel,
    command: &str,
    args: &[String],
) -> Result<(), String> {
    let status = Command::new(kernel.upstream_codex_binary())
        .arg(command)
        .args(args)
        .status()
        .map_err(|error| {
            format!(
                "could not start bundled Codex at {}: {error}",
                kernel.upstream_codex_binary().display()
            )
        })?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("bundled Codex {command} exited with {status}"))
    }
}

/// Runs an agent turn through the shared Rust SDK. `codex` remains an alias
/// so existing product scripts use the SDK path rather than raw process
/// argument forwarding.
fn run_agent(kernel: &MahayanaKernel, args: &[String]) -> Result<(), String> {
    let request = match args.first().map(String::as_str) {
        Some("--json") => {
            let source = args
                .get(1)
                .ok_or_else(|| "usage: mahayana agent --json '<request>'".to_string())?;
            let request = parse_object(source, "Codex Rust SDK request")?;
            if request.get("prompt").and_then(Value::as_str).is_none() {
                return Err("Codex Rust SDK request requires a non-empty prompt".to_string());
            }
            request
        }
        _ if args.is_empty() => {
            return Err("usage: mahayana agent <prompt> | --json '<request>'".to_string())
        }
        _ => json!({"prompt": args.join(" ")}),
    };
    let mut request = request
        .as_object()
        .cloned()
        .ok_or_else(|| "Codex Rust SDK request must be a JSON object".to_string())?;
    request.insert(
        "@type".to_string(),
        Value::String("mahayana.codex.run".to_string()),
    );
    let response = kernel
        .execute(Value::Object(request))
        .map_err(|error| error.to_string())?;
    println!("{response}");
    Ok(())
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
        Some("chat") => {
            let miniapp_id = args
                .get(1)
                .ok_or_else(|| "usage: mahayana miniapp chat <miniapp-id> <message>".to_string())?;
            let message = args.get(2..).unwrap_or_default().join(" ");
            if message.trim().is_empty() {
                return Err("usage: mahayana miniapp chat <miniapp-id> <message>".to_string());
            }
            print_kernel_response(
                kernel,
                json!({
                    "@type":"mahayana.miniapp.chat",
                    "miniAppId":miniapp_id,
                    "message":message,
                }),
            )
        }
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
        _ => Err("usage: mahayana miniapp chat|inspect|evaluate|request".to_string()),
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
        "mahayana.codex.run" => ("mahayana.codex.run", true),
        "mahayana.telegram.create_client" => ("mahayana.telegram.createClient", false),
        "mahayana.telegram.execute" => ("mahayana.telegram.execute", true),
        "mahayana.miniapp.inspect" => ("mahayana.miniapp.inspect", false),
        "mahayana.miniapp.evaluate" => ("mahayana.miniapp.evaluate", false),
        "mahayana.miniapp.execute" => ("mahayana.miniapp.execute", true),
        "mahayana.miniapp.chat" => ("mahayana.miniapp.chat", true),
        "mahayana.auth.status" => ("mahayana.auth.status", false),
        "mahayana.auth.alipay_start" => ("mahayana.auth.alipay.start", false),
        "mahayana.auth.alipay_complete" => ("mahayana.auth.alipay.complete", true),
        "mahayana.auth.alipay_poll" => ("mahayana.auth.alipay.poll", false),
        "mahayana.auth.alipay_sdk_start" => ("mahayana.auth.alipay.sdk.start", false),
        "mahayana.auth.alipay_sdk_complete" => ("mahayana.auth.alipay.sdk.complete", true),
        "mahayana.auth.logout" => ("mahayana.auth.logout", true),
        "mahayana.contacts.list" => ("mahayana.contacts.list", false),
        "mahayana.contacts.search" => ("mahayana.contacts.search", false),
        "mahayana.contacts.add" => ("mahayana.contacts.add", true),
        "mahayana.contacts.requests" => ("mahayana.contacts.requests", false),
        "mahayana.contacts.accept" => ("mahayana.contacts.accept", true),
        "mahayana.messages.list" => ("mahayana.messages.list", false),
        "mahayana.messages.send" => ("mahayana.messages.send", true),
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
    let result = redact_secrets(&result);
    Ok(json!({
        "content": [{"type": "text", "text": result.to_string()}],
    }))
}

fn mcp_tools() -> Vec<Value> {
    vec![
        mcp_tool("mahayana.status", "Show the active shared Rust kernel and upstream Codex path.", json!({"type":"object","properties":{}}), true),
        mcp_tool("mahayana.codex.run", "Run a Codex turn through the shared Rust SDK. An explicit confirmation is required because the agent may use tools.", json!({"type":"object","properties":{"prompt":{"type":"string","minLength":1},"threadId":{"type":"string"},"model":{"type":"string"},"workingDirectory":{"type":"string"},"sandbox":{"type":"string","enum":["read-only","workspace-write","danger-full-access"]},"approvalPolicy":{"type":"string","enum":["never","on-request","on-failure","untrusted"]},"confirmed":{"type":"boolean"}},"required":["prompt","confirmed"]}), false),
        mcp_tool("mahayana.telegram.create_client", "Create an in-process Rust Telegram client for subsequent tool calls.", json!({"type":"object","properties":{}}), false),
        mcp_tool("mahayana.telegram.execute", "Execute a Telegram Rust runtime request. Networked/authentication actions require confirmation.", json!({"type":"object","properties":{"clientId":{"type":"integer","minimum":1},"request":{"type":"object"},"confirmed":{"type":"boolean"}},"required":["clientId","request","confirmed"]}), false),
        mcp_tool("mahayana.miniapp.inspect", "Inspect a web mini-app manifest against the shared Rust capability registry.", json!({"type":"object","properties":{"manifestPath":{"type":"string"}},"required":["manifestPath"]}), true),
        mcp_tool("mahayana.miniapp.evaluate", "Evaluate a mini-app host-method permission without invoking the method.", json!({"type":"object","properties":{"method":{"type":"string"},"declaredPermissions":{"type":"array","items":{"type":"string"}},"platform":{"type":"string"},"trustedOfficial":{"type":"boolean"}},"required":["method"]}), true),
        mcp_tool("mahayana.miniapp.execute", "Execute an approved Rust mini-app host request. Network and mutation requests require confirmation.", json!({"type":"object","properties":{"request":{"type":"object"},"confirmed":{"type":"boolean"}},"required":["request","confirmed"]}), false),
        mcp_tool("mahayana.miniapp.chat", "Talk to or operate a Mahayana mini-app through the shared Codex Rust SDK. Confirmation is required because a mini-app turn may invoke tools.", json!({"type":"object","properties":{"miniAppId":{"type":"string","minLength":1},"message":{"type":"string","minLength":1},"threadId":{"type":"string"},"confirmed":{"type":"boolean"}},"required":["miniAppId","message","confirmed"]}), false),
        mcp_tool("mahayana.auth.status", "Show the current Mahayana software account session (Alipay login).", json!({"type":"object","properties":{}}), true),
        mcp_tool("mahayana.auth.alipay_start", "Create an Alipay authorization URL for the Mahayana software account.", json!({"type":"object","properties":{"platform":{"type":"string","default":"cli"}}}), true),
        mcp_tool("mahayana.auth.alipay_complete", "Complete Mahayana Alipay login from the callback auth code and store the account session in Rust.", json!({"type":"object","properties":{"authCode":{"type":"string","minLength":1},"state":{"type":"string"},"confirmed":{"type":"boolean"}},"required":["authCode","confirmed"]}), false),
        mcp_tool("mahayana.auth.alipay_poll", "Poll a pending CLI Alipay authorization. A successful result is stored in the Rust-owned account session.", json!({"type":"object","properties":{"state":{"type":"string","minLength":1}},"required":["state"]}), true),
        mcp_tool("mahayana.auth.alipay_sdk_start", "Create the Alipay mobile SDK authorization string for the Mahayana software account.", json!({"type":"object","properties":{}}), true),
        mcp_tool("mahayana.auth.alipay_sdk_complete", "Complete an Alipay mobile SDK login and store the software account session in Rust.", json!({"type":"object","properties":{"authCode":{"type":"string","minLength":1},"targetId":{"type":"string"},"confirmed":{"type":"boolean"}},"required":["authCode","confirmed"]}), false),
        mcp_tool("mahayana.auth.logout", "Remove the locally stored Mahayana software account session.", json!({"type":"object","properties":{"confirmed":{"type":"boolean"}},"required":["confirmed"]}), false),
        mcp_tool("mahayana.contacts.list", "List the current Mahayana account's friends.", json!({"type":"object","properties":{}}), true),
        mcp_tool("mahayana.contacts.search", "Find Mahayana contacts by display name, username, account id, or user number.", json!({"type":"object","properties":{"query":{"type":"string","minLength":1}},"required":["query"]}), true),
        mcp_tool("mahayana.contacts.add", "Send a friend request to a Mahayana contact.", json!({"type":"object","properties":{"contact":{"type":"string","minLength":1},"message":{"type":"string"},"confirmed":{"type":"boolean"}},"required":["contact","confirmed"]}), false),
        mcp_tool("mahayana.contacts.requests", "List incoming Mahayana friend requests.", json!({"type":"object","properties":{}}), true),
        mcp_tool("mahayana.contacts.accept", "Accept an incoming Mahayana friend request.", json!({"type":"object","properties":{"requestId":{"oneOf":[{"type":"string"},{"type":"integer"}]},"confirmed":{"type":"boolean"}},"required":["requestId","confirmed"]}), false),
        mcp_tool("mahayana.messages.list", "Read direct messages exchanged with a Mahayana friend.", json!({"type":"object","properties":{"contact":{"type":"string","minLength":1},"limit":{"type":"integer","minimum":1,"maximum":200}},"required":["contact"]}), true),
        mcp_tool("mahayana.messages.send", "Send a direct message to an existing Mahayana friend.", json!({"type":"object","properties":{"contact":{"type":"string","minLength":1},"text":{"type":"string","minLength":1,"maxLength":4000},"clientRequestId":{"type":"string"},"confirmed":{"type":"boolean"}},"required":["contact","text","confirmed"]}), false),
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
         mahayana                         # open Codex-style Mahayana TUI\n\
         mahayana chat [PROMPT]           # open TUI with optional prompt\n\
         mahayana status\n\
         mahayana agent <prompt>\n\
         mahayana agent --json '<sdk request>'\n\
         mahayana codex <prompt>  (alias for `agent`)\n\
         mahayana login [complete <auth-code> [state]]\n\
         mahayana auth status|login|logout\n\
         mahayana contacts list|search|add|requests|accept\n\
         mahayana messages list|send\n\
         mahayana codex-login|codex-logout|doctor [CODEX_ARGS...]\n\
         mahayana mcp serve|install|install-global-dharma|print-install\n\
         mahayana telegram status|request '<json>'\n\
         mahayana miniapp chat <miniapp-id> <message>\n\
         mahayana miniapp inspect <manifest.json>\n\
         mahayana miniapp evaluate <method> [permission,...] [platform]\n\
         mahayana miniapp request '<json>'\n\n\
         The release includes Codex at lib/mahayana/codex; MAHAYANA_CODEX_BIN is a development override only.\n\
         Agent turns are driven by the Codex Rust SDK, not raw argument forwarding."
    );
}
