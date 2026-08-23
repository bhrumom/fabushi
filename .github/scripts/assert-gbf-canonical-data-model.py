#!/usr/bin/env python3
from pathlib import Path

root = Path('.')

# Keep the executable CI contract self-contained because the Electron Feature
# Host job intentionally uses a narrow sparse checkout. The matching JSON file
# under projects/.../evidence/GBF-601 remains the human/audit representation of
# this same authority map.
models = {
    "sessionLifecycle": "third_party/mahayana/mahayana-rs/mahayana-kernel/src/resilience.rs::SessionRegistry",
    "operationLifecycle": "third_party/mahayana/mahayana-rs/mahayana-feature-host/src/implementation.rs::operations",
    "hostContract": "third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs::FeatureCommand/HostEvent",
    "agentRuntime": "third_party/mahayana/mahayana-rs/mahayana-runtime/src/lib.rs::MahayanaRuntime",
    "computerTarget": "third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs::ComputerControlTarget",
    "rendererHostEdge": "desktop/electron/mahayana-edge.cjs::MAHAYANA_EDGE",
    "nativeCapabilityEdge": "desktop/electron/native-edge.cjs::NATIVE_EDGE",
    "conversation": "third_party/mahayana/mahayana-rs/mahayana-conversation/src/lib.rs",
    "permissions": "third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs::ProductHostSettings",
}

for name, target in models.items():
    path = target.split('::', 1)[0]
    if not (root / path).exists():
        raise SystemExit(f'GBF canonical model missing {name}: {path}')

for path in (
    "frontend/apps/web/src/lib/grok-agent",
    "frontend/apps/web/src/lib/grok-bot",
    "vendor/grok-bot-0.20.0",
):
    if (root / path).exists():
        raise SystemExit(f'GBF parallel authority returned: {path}')

print(f"GBF canonical data model passed: {len(models)} authorities, zero Grok parallel authorities.")
