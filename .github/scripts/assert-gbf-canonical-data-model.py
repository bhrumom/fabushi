#!/usr/bin/env python3
import subprocess


def tracked(path: str) -> bool:
    result = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", "HEAD", "--", path],
        check=True,
        capture_output=True,
        text=True,
    )
    return bool(result.stdout.strip())


# Keep the executable CI contract self-contained because the Electron Feature
# Host job intentionally uses a narrow sparse checkout. Existence is checked
# against the Git commit tree rather than the materialized worktree, so the gate
# remains exact even when an authority is intentionally not checked out.
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
    path = target.split("::", 1)[0]
    if not tracked(path):
        raise SystemExit(f"GBF canonical model missing {name}: {path}")

for path in (
    "frontend/apps/web/src/lib/grok-agent",
    "frontend/apps/web/src/lib/grok-bot",
    "vendor/grok-bot-0.20.0",
):
    if tracked(path):
        raise SystemExit(f"GBF parallel authority returned: {path}")

print(f"GBF canonical data model passed: {len(models)} authorities, zero Grok parallel authorities.")
