from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label} marker changed in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


sidecar = Path("integrations/rustdesk-sidecar/overlay/src/bin/fabushi_sidecar.rs")
replace_once(
    sidecar,
    "use hbb_common::{message_proto::*, rendezvous_proto::ConnType};\n",
    "use hbb_common::{config::Config, message_proto::*, rendezvous_proto::ConnType};\n",
    "sidecar Config import",
)
replace_once(
    sidecar,
    'const MAX_FRAME_BYTES: usize = 64 * 1024 * 1024;\n',
    '''const MAX_FRAME_BYTES: usize = 64 * 1024 * 1024;\n\nfn managed_network() -> Result<(), String> {\n    let server = std::env::var("FABUSHI_RUSTDESK_RENDEZVOUS_SERVER").unwrap_or_default().trim().to_owned();\n    let key = std::env::var("FABUSHI_RUSTDESK_PUBLIC_KEY").unwrap_or_default().trim().to_owned();\n    if server.is_empty() || server.len() > 512 || server.chars().any(|c| c.is_control() || c.is_whitespace()) {\n        return Err("managed-rendezvous-unavailable".into());\n    }\n    if key.len() < 16 || key.len() > 4096 || key.chars().any(|c| c.is_control()) {\n        return Err("managed-rendezvous-key-unavailable".into());\n    }\n    Config::set_option("custom-rendezvous-server".into(), server);\n    Config::set_option("key".into(), key);\n    Ok(())\n}\n''',
    "sidecar managed network function",
)
replace_once(
    sidecar,
    '''        Command::Open { session_id, peer_id, password, force_relay, grant } => {\n            if !valid_id(&session_id, 160) || !valid_id(&peer_id, 160) { return Err("invalid-session-or-peer-id".into()); }\n''',
    '''        Command::Open { session_id, peer_id, password, force_relay, grant } => {\n            managed_network()?;\n            if !valid_id(&session_id, 160) || !valid_id(&peer_id, 160) { return Err("invalid-session-or-peer-id".into()); }\n''',
    "sidecar fail closed on open",
)

host = Path("integrations/rustdesk-sidecar/overlay/src/bin/fabushi_host_daemon.rs")
host.write_text('''// SPDX-License-Identifier: AGPL-3.0-only\n// Fabushi-owned entry point for the pinned RustDesk host runtime. The daemon\n// keeps RustDesk transport in a separate process and never receives Fabushi\n// account credentials. Authorization remains in the Fabushi control plane.\n\nuse hbb_common::config::Config;\n\nfn managed_network() -> Result<(), &'static str> {\n    let server = std::env::var("FABUSHI_RUSTDESK_RENDEZVOUS_SERVER").unwrap_or_default().trim().to_owned();\n    let key = std::env::var("FABUSHI_RUSTDESK_PUBLIC_KEY").unwrap_or_default().trim().to_owned();\n    if server.is_empty() || server.len() > 512 || server.chars().any(|c| c.is_control() || c.is_whitespace()) {\n        return Err("managed-rendezvous-unavailable");\n    }\n    if key.len() < 16 || key.len() > 4096 || key.chars().any(|c| c.is_control()) {\n        return Err("managed-rendezvous-key-unavailable");\n    }\n    Config::set_option("custom-rendezvous-server".into(), server);\n    Config::set_option("key".into(), key);\n    Ok(())\n}\n\nfn main() {\n    if let Err(error) = managed_network() {\n        eprintln!("{error}");\n        std::process::exit(78);\n    }\n    librustdesk::start_server(true, false);\n}\n''', encoding="utf-8")

process = Path("desktop/electron/rustdesk-sidecar-process.cjs")
replace_once(
    process,
    '''function cleanEnvironment(env = process.env) {\n  const keep = ['PATH', 'SystemRoot', 'WINDIR', 'HOME', 'USERPROFILE', 'TMPDIR', 'TMP', 'TEMP', 'LANG', 'LC_ALL', 'DISPLAY', 'WAYLAND_DISPLAY', 'XDG_RUNTIME_DIR', 'DBUS_SESSION_BUS_ADDRESS'];\n  return Object.fromEntries(keep.flatMap((key) => env[key] == null ? [] : [[key, String(env[key])]]));\n}\n''',
    '''function managedNetworkConfig(env = process.env) {\n  const rendezvousServer = String(env.FABUSHI_RUSTDESK_RENDEZVOUS_SERVER || '').trim();\n  const publicKey = String(env.FABUSHI_RUSTDESK_PUBLIC_KEY || '').trim();\n  const validServer = rendezvousServer.length > 0 && rendezvousServer.length <= 512 && !/[\\s\\x00-\\x1f\\x7f]/.test(rendezvousServer);\n  const validKey = publicKey.length >= 16 && publicKey.length <= 4096 && !/[\\x00-\\x1f\\x7f]/.test(publicKey);\n  return Object.freeze({ configured: validServer && validKey, rendezvousServer, publicKey });\n}\n\nfunction cleanEnvironment(env = process.env) {\n  const keep = ['PATH', 'SystemRoot', 'WINDIR', 'HOME', 'USERPROFILE', 'TMPDIR', 'TMP', 'TEMP', 'LANG', 'LC_ALL', 'DISPLAY', 'WAYLAND_DISPLAY', 'XDG_RUNTIME_DIR', 'DBUS_SESSION_BUS_ADDRESS', 'FABUSHI_RUSTDESK_RENDEZVOUS_SERVER', 'FABUSHI_RUSTDESK_PUBLIC_KEY'];\n  return Object.fromEntries(keep.flatMap((key) => env[key] == null ? [] : [[key, String(env[key])]]));\n}\n''',
    "managed network env",
)
replace_once(
    process,
    '''    const executable = this.executablePath();\n    if (!executable) throw new Error('RustDesk sidecar binary is unavailable.');\n''',
    '''    const executable = this.executablePath();\n    if (!executable) throw new Error('RustDesk sidecar binary is unavailable.');\n    if (!managedNetworkConfig(this.env).configured) throw new Error('Fabushi-managed RustDesk rendezvous is not configured.');\n''',
    "sidecar process managed config gate",
)
replace_once(
    process,
    "module.exports = { PROTOCOL, RustDeskSidecarProcess, binaryPath, cleanEnvironment };\n",
    "module.exports = { PROTOCOL, RustDeskSidecarProcess, binaryPath, cleanEnvironment, managedNetworkConfig };\n",
    "sidecar exports managed config",
)

host_process = Path("desktop/electron/rustdesk-host-daemon-process.cjs")
replace_once(
    host_process,
    "const { cleanEnvironment } = require('./rustdesk-sidecar-process.cjs');\n",
    "const { cleanEnvironment, managedNetworkConfig } = require('./rustdesk-sidecar-process.cjs');\n",
    "host managed config import",
)
replace_once(
    host_process,
    '''    const executable = this.executablePath();\n    if (!executable) return { available: false, running: false, startedAtMs: 0 };\n''',
    '''    const executable = this.executablePath();\n    if (!executable || !managedNetworkConfig(this.env).configured) return { available: false, configured: false, running: false, startedAtMs: 0 };\n''',
    "host start fail closed",
)
replace_once(
    host_process,
    '''    return { available: true, running: true, startedAtMs: this.startedAtMs };\n  }\n\n  status() {\n    return {\n      available: Boolean(this.executablePath()),\n      running: Boolean(this.child),\n''',
    '''    return { available: true, configured: true, running: true, startedAtMs: this.startedAtMs };\n  }\n\n  status() {\n    const configured = managedNetworkConfig(this.env).configured;\n    return {\n      available: Boolean(this.executablePath()) && configured,\n      configured,\n      running: Boolean(this.child),\n''',
    "host status managed config",
)

readme = Path("integrations/rustdesk-sidecar/README.md")
text = readme.read_text(encoding="utf-8")
notice = '''\n### Managed rendezvous / relay boundary\n\nThe native provider is fail-closed unless Fabushi supplies both `FABUSHI_RUSTDESK_RENDEZVOUS_SERVER` and `FABUSHI_RUSTDESK_PUBLIC_KEY`. These are provider-infrastructure values only; account cookies, bearer tokens, device credentials, and session authorization tokens remain outside the AGPL process. The overlay writes the configured server/key into RustDesk `Config` before opening a session or starting the host, so production does not silently fall back to RustDesk public rendezvous infrastructure. When this configuration is absent, Fabushi must report the native provider unavailable and retain the existing authenticated Fabushi transport path.\n'''
if "### Managed rendezvous / relay boundary" not in text:
    readme.write_text(text.rstrip() + "\n" + notice, encoding="utf-8")
