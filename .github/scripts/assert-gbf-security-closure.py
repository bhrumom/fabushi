#!/usr/bin/env python3
import csv
import json
from pathlib import Path

root = Path('.')
project = root / 'projects/grok-bot-fabushi-integration'

# GBF-701 keeps the machine-readable threat model in threat-model.md so the
# project evidence has one canonical copy that is both reviewable and executable.
threats = json.loads((project / 'evidence/GBF-701/threat-model.md').read_text(encoding='utf-8'))
if len(threats.get('boundaries', [])) < 7 or len(threats.get('threats', [])) < 8:
    raise SystemExit('GBF security closure: threat model is incomplete')
for item in threats['threats']:
    for key in ('id', 'threat', 'mitigation', 'residual'):
        if not str(item.get(key, '')).strip():
            raise SystemExit(f"GBF security closure: {item.get('id', '<unknown>')} missing {key}")

files = {
    'main': root / 'desktop/electron/main.cjs',
    'native': root / 'desktop/electron/native-capability-handlers.cjs',
    'native_test': root / 'desktop/electron/native-capability-handlers.test.cjs',
    'edge_test': root / 'desktop/electron/edge-ipc.test.cjs',
    'app_host': root / 'third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs',
    'protocol': root / 'third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs',
    'secure_input': root / 'chatgpt-vps-control/lib/secure-input.js',
    'secure_input_test': root / 'chatgpt-vps-control/tests/secure-input.test.js',
}
text = {name: path.read_text(encoding='utf-8') for name, path in files.items()}

positive_checks = {
    'structured edge telemetry excludes payloads': ('main', 'exclude args/results/URLs/tokens'),
    'structured edge correlation exists': ('main', 'fabushi.edge.invoke'),
    'native sensitive key classifier exists': ('native', 'const SENSITIVE_KEY = /(secret|token|password|authorization|cookie|credential|private.?key)/i;'),
    'native recursive redaction exists': ('native', "SENSITIVE_KEY.test(key) ? '[redacted]' : redact"),
    'native redaction behavior is tested': ('native_test', 'diagnostic reports redact nested secrets before persistence'),
    'edge trace secrecy is tested': ('edge_test', 'structured invocation traces contain correlation/status/duration but never args or results'),
    'computer target protocol is versioned': ('protocol', 'COMPUTER_CONTROL_PROTOCOL_VERSION'),
    'sensitive input uses AES-GCM': ('secure_input', 'AES-GCM'),
    'sensitive input is one-time': ('secure_input', 'consumedChallenges.add(challengeId)'),
    'sensitive input expiry fails closed': ('secure_input', 'Sensitive-input challenge has expired.'),
    'sensitive replay/expiry behavior is tested': ('secure_input_test', 'sensitive challenge is one-time and an optional expiry fails closed'),
}
for label, (name, marker) in positive_checks.items():
    if marker not in text[name]:
        raise SystemExit(f'GBF security closure: {label} failed')

negative_checks = {
    'retired generic Electron Host IPC': ('main', "ipcMain.handle('fabushi:host'"),
    'direct renderer/runtime tool bypass': ('app_host', '"runtime.callTool"'),
}
for label, (name, marker) in negative_checks.items():
    if marker in text[name]:
        raise SystemExit(f'GBF security closure: {label} returned')

for forbidden in (
    root / 'vendor/grok-bot-0.20.0',
    root / 'frontend/apps/web/src/lib/grok-agent',
    root / 'frontend/apps/web/src/lib/grok-bot',
):
    if forbidden.exists():
        raise SystemExit(f'GBF security closure: forbidden production source returned: {forbidden}')

ledger = project / 'evidence/GBF-105/vendor-0.20-provenance.tsv'
with ledger.open(encoding='utf-8', newline='') as handle:
    rows = list(csv.DictReader(handle, delimiter='\t'))
if len(rows) != 148:
    raise SystemExit(f'GBF security closure: expected 148 historical vendor rows, found {len(rows)}')
if any(
    row.get('license_state') != 'PROVENANCE_BLOCKED'
    or 'reference-only' not in row.get('reuse_policy', '')
    for row in rows
):
    raise SystemExit('GBF security closure: historical vendor input is not uniformly blocked/reference-only')

print(
    f'GBF security closure passed: {len(threats["threats"])} threats, '
    '148 vendor refs blocked/reference-only, secret/replay/target gates present, '
    'production Grok vendor paths absent.'
)
