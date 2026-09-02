#!/usr/bin/env python3
from pathlib import Path
import re

root = Path('.')
edge = (root / 'desktop/electron/mahayana-edge.cjs').read_text(encoding='utf-8')
coordinator = (root / 'frontend/apps/web/src/lib/mahayana-host/coordinator.ts').read_text(encoding='utf-8')
app_host = (root / 'third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs').read_text(encoding='utf-8')
feature_host = (root / 'third_party/mahayana/mahayana-rs/mahayana-feature-host/src/implementation.rs').read_text(encoding='utf-8')
runtime = (root / 'third_party/mahayana/mahayana-rs/mahayana-runtime/src/lib.rs').read_text(encoding='utf-8')
kernel_resilience = (root / 'third_party/mahayana/mahayana-rs/mahayana-kernel/src/resilience.rs').read_text(encoding='utf-8')
remote_device = (root / 'desktop/electron/remote-device-agent-supervisor.cjs').read_text(encoding='utf-8')
rustdesk_sidecar = (root / 'desktop/electron/rustdesk-sidecar-process.cjs').read_text(encoding='utf-8')
rustdesk_bootstrap = (root / 'desktop/electron/rustdesk-host-bootstrap.cjs').read_text(encoding='utf-8')

method_block = re.search(r'const methodNames = \[([\s\S]*?)\];', edge)
if not method_block:
    raise SystemExit('GBF runtime convergence: desktop Mahayana edge method list missing')
methods = re.findall(r"'([^']+)'", method_block.group(1))
invalid = [m for m in methods if m != 'host.platform' and not m.startswith('feature.')]
if invalid:
    raise SystemExit('GBF runtime convergence: renderer bypass methods exposed: ' + ', '.join(invalid))

required = {
    'coordinator delegates all RuntimeCommand execution to transport': (coordinator, 'return this.transport.execute(command).then((accepted) => {'),
    'AppHost feature.execute parses FeatureCommand': (app_host, 'let command: FeatureCommand = serde_json::from_value(command_value)'),
    'AppHost feature.execute delegates to FeatureHost': (app_host, '.feature\n            .execute(command)'),
    'FeatureHost MCP call enters MahayanaRuntime': (feature_host, 'self.runtime()?.execute(RuntimeCommand::McpToolCall {'),
    'FeatureHost MCP call writes action audit': (feature_host, '"kind": "mcpToolCall"'),
    'Runtime MCP call enters agent backend': (runtime, '.block_on(backend.call_mcp_tool(&server, &tool, arguments))'),
    'FeatureHost interrupt rejects unknown operations': (feature_host, 'if !state.operations.contains(operation_id)'),
    'Kernel owns explicit resume transition': (kernel_resilience, 'pub fn resume(&mut self, id: &SessionId, at_ms: i64)'),
    'Kernel tests invalid lifecycle fail closed': (kernel_resilience, 'fn invalid_lifecycle_transition_fails_closed()'),
}
for label, (text, needle) in required.items():
    if needle not in text:
        raise SystemExit(f'GBF runtime convergence: missing {label}: {needle}')

if '"runtime.callTool"' in app_host or 'fn call_runtime_tool' in app_host:
    raise SystemExit('GBF runtime convergence: direct runtime.callTool bypass still exists in AppHost')

for legacy in [
    root / 'frontend/apps/web/src/lib/grok-agent',
    root / 'frontend/apps/web/src/lib/grok-bot',
    root / 'vendor/grok-bot-0.20.0',
]:
    if legacy.exists():
        raise SystemExit(f'GBF runtime convergence: retired Grok runtime path exists: {legacy}')

# Desktop JS may only spawn the Rust Host, isolated local ASR provider, the
# installed application's pinned account-scoped remote-device transport, and
# the separately distributed RustDesk AGPL provider boundary. RustDesk is
# explicitly constrained to the pinned sidecar/bootstrap pair below; adding
# any other desktop process surface still fails closed.
for label, needle in {
    'official packaged device gateway': "const OFFICIAL_DEVICE_GATEWAY_URL = 'wss://fabushi-mcp.ombhrum.com/agent'",
    'content-addressed embedded device agent': "path.join(root, 'bin', 'fabushi-device-agent.js')",
    'refresh session excluded from transport': "FABUSHI_ACCOUNT_SESSION_FILE: ''",
    'access token passed by owner-only file': 'FABUSHI_ACCOUNT_TOKEN_FILE: this.tokenFile',
    'logout credential cleanup': 'this.fs.rmSync(this.tokenFile, { force: true })',
}.items():
    if needle not in remote_device:
        raise SystemExit(f'GBF runtime convergence: missing {label}: {needle}')

for label, (text, needle) in {
    'RustDesk sidecar uses child_process only behind dedicated provider boundary': (rustdesk_sidecar, 'node:child_process'),
    'RustDesk sidecar requires pinned packaged executable resolution': (rustdesk_sidecar, 'executablePath'),
    'RustDesk host bootstrap uses child_process only behind dedicated provider boundary': (rustdesk_bootstrap, 'node:child_process'),
}.items():
    if needle not in text:
        raise SystemExit(f'GBF runtime convergence: missing {label}: {needle}')

process_hits = []
for base in [root / 'desktop', root / 'frontend/apps/web/src']:
    for path in base.rglob('*'):
        if not path.is_file() or path.suffix not in {'.cjs', '.js', '.ts', '.tsx'}:
            continue
        text = path.read_text(encoding='utf-8', errors='ignore')
        if "node:child_process" in text or re.search(r'\b(?:spawn|execFile|exec)\s*\(', text):
            rel = path.as_posix()
            if rel not in {
                'desktop/electron/host-process.cjs',
                'desktop/electron/offline-asr.cjs',
                'desktop/electron/remote-device-agent-supervisor.cjs',
                'desktop/electron/remote-device-agent-supervisor.test.cjs',
                'desktop/electron/rustdesk-host-bootstrap.cjs',
                'desktop/electron/rustdesk-host-bootstrap.test.cjs',
                'desktop/electron/rustdesk-sidecar-process.cjs',
                'desktop/electron/rustdesk-sidecar-process.test.cjs',
            }:
                # Ignore RegExp.exec; only child_process import or known process-call identifiers count.
                if "node:child_process" in text or re.search(r'\b(?:spawn|execFile)\s*\(', text):
                    process_hits.append(rel)
if process_hits:
    raise SystemExit('GBF runtime convergence: unapproved desktop process execution surface: ' + ', '.join(sorted(set(process_hits))))

for needle in [
    'if !settings.local_execution {',
    'LocalToolPermission::Never',
    'requires an explicit approval while local-tool permission is Ask',
]:
    if needle not in feature_host:
        raise SystemExit(f'GBF runtime convergence: local execution policy guard missing: {needle}')

print(f'GBF runtime convergence passed: {len(methods)} renderer Host methods; one FeatureHost execution path; approved RustDesk provider boundary; no direct runtime.callTool bypass.')
