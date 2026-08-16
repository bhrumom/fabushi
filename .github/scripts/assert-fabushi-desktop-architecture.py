#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_FILES = (
    "desktop/electron/edge-ipc.cjs",
    "desktop/electron/mahayana-edge.cjs",
    "desktop/electron/native-edge.cjs",
    "desktop/electron/native-capability-handlers.cjs",
    "desktop/electron/main.cjs",
    "desktop/electron/preload.cjs",
    "desktop/src/edge/ipc.ts",
    "desktop/src/edge/contracts/native-capabilities.ts",
    "frontend/apps/web/src/lib/mahayana-host/coordinator.ts",
    "frontend/apps/web/src/lib/mahayana-host/contracts.ts",
    "frontend/apps/web/src/lib/mahayana-host/electron-transport.ts",
    "frontend/apps/web/src/lib/fabushi-runtime/agent-utils.ts",
    "frontend/apps/web/src/lib/fabushi-runtime/agent-notifications.ts",
    "frontend/apps/web/src/lib/fabushi-runtime/collaboration.ts",
    "frontend/apps/web/src/lib/fabushi-runtime/interactions.ts",
    "frontend/apps/web/src/lib/fabushi-runtime/native-desktop.ts",
    ".github/scripts/assert-native-desktop-edge-parity.py",
)

REQUIRED_SNIPPETS = {
    "desktop/electron/edge-ipc.cjs": (
        "fabushi-edge:${edge}:call:${method}",
        "fabushi-edge:${edge}:event:${event}",
        "serveMainEdge",
        "createRendererEdge",
    ),
    "desktop/electron/native-edge.cjs": (
        "getDesktopEnvironment",
        "getWindowState",
        "setThemePreference",
        "readClientPersistence",
        "writeClientPersistence",
    ),
    "desktop/electron/preload.cjs": (
        "fabushiNative",
        "invokeEdge",
        "mahayana-host",
        "native-desktop",
        "runtime-event",
    ),
    "frontend/apps/web/src/lib/mahayana-host/coordinator.ts": (
        "class MahayanaCoordinator",
        "getAgentTranscriptTail",
        "promptAcceptanceStatus",
        "setAgentAvatarBytes",
        "listAutomations",
        "listWorkflows",
        "getSharingState",
        "reactToMessage",
        "voteFeedback",
    ),
    "frontend/apps/web/src/lib/fabushi-runtime/collaboration.ts": (
        'CollaborationScope = "local-device"',
        "BroadcastChannel",
        "createRoomInvite",
        "respondToRoomJoinRequest",
        "setSharedRoomTyping",
    ),
}



def fail(message: str) -> None:
    print(f"architecture guard failed: {message}", file=sys.stderr)
    raise SystemExit(1)


for relative in REQUIRED_FILES:
    if not (ROOT / relative).is_file():
        fail(f"required file is missing: {relative}")

for relative, snippets in REQUIRED_SNIPPETS.items():
    text = (ROOT / relative).read_text(encoding="utf-8")
    for snippet in snippets:
        if snippet not in text:
            fail(f"{relative} is missing required capability marker: {snippet}")

print("Fabushi desktop architecture guard passed")
