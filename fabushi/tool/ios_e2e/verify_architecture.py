#!/usr/bin/env python3
"""Fail CI if iOS MiniApp E2E regresses to a fake-install architecture."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
WORKFLOW = ROOT / ".github/workflows/ios-external-miniapp-e2e.yml"
FLOW = ROOT / "fabushi/tool/ios_e2e/flows/global_fabushi_search_open.v1.json"
PRODUCT = ROOT / "third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs"
INSTALLER = (
    ROOT
    / "third_party/mahayana/mahayana-rs/mahayana-plugin-host/src/marketplace_installer.rs"
)
MARKETPLACE_SERVICE = (
    ROOT / "fabushi/lib/services/miniapp/mahayana_marketplace_service.dart"
)
HOST = ROOT / "fabushi/lib/screens/mini_app_host_screen.dart"
CONTROL = ROOT / "fabushi/lib/services/miniapp/mahayana_e2e_control_io.dart"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"iOS MiniApp E2E architecture violation: {message}")


def main() -> int:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    product = PRODUCT.read_text(encoding="utf-8")
    installer = INSTALLER.read_text(encoding="utf-8")
    service = MARKETPLACE_SERVICE.read_text(encoding="utf-8")
    host = HOST.read_text(encoding="utf-8")
    control = CONTROL.read_text(encoding="utf-8")
    flow = json.loads(FLOW.read_text(encoding="utf-8"))
    flow_text = json.dumps(flow, ensure_ascii=False)

    forbidden_workflow = {
        r"\bmahayana\s+marketplace\s+install\b":
            "the host CLI must not simulate mobile installation",
        r"\bcp\s+-R\b":
            "the workflow must not copy plugin trees into the app sandbox",
        r"workspace/\.agents/plugins":
            "mobile tests must not stage repository-style CLI installs",
    }
    for pattern, message in forbidden_workflow.items():
        require(re.search(pattern, workflow) is None, message)

    require(
        "--dart-define=FABUSHI_E2E_CONTROL=true" in workflow,
        "the E2E control channel must be opt-in at build time",
    )
    require(
        "!kDebugMode || !_e2eControlEnabled" in control,
        "E2E control must remain debug-only and explicitly enabled",
    )
    require(
        "MahayanaMarketplaceService.instance.install" in control,
        "control installation must delegate to the production marketplace service",
    )
    require(
        "--method marketplace.install" not in workflow,
        "the black-box workflow must install through UI, not the control channel",
    )
    require("appium@3.6.0" in workflow, "Appium must be pinned to 3.6.0")
    require(
        "xcuitest@12.3.1" in workflow,
        "the XCUITest driver must be pinned to 12.3.1",
    )
    require("PLUGIN_ID: global-dharma" in workflow, "the canary plugin id must be exact")

    require(
        '"mahayana.marketplace.install"' in product,
        "the product command router must own marketplace installation",
    )
    require(
        "install_marketplace_bundle_to_codex_home" in product,
        "product install must delegate to the shared production installer",
    )
    require(
        '"protocol": "mahayana.marketplace.install-receipt.v1"' in installer,
        "the installer must write a versioned verified receipt",
    )
    require(
        "fs::rename(&staging, &destination)" in installer,
        "the production install must become visible atomically",
    )
    require(
        "MahayanaMarketplaceService.instance.install" in (
            ROOT / "fabushi/lib/widgets/layout/telegram_chat_list.dart"
        ).read_text(encoding="utf-8"),
        "the user-visible install action must call the production marketplace service",
    )
    require(
        "'@type': 'mahayana.marketplace.install'" in service,
        "Flutter marketplace service must use the native product install command",
    )
    require(
        "_webViewLoaded ? 'ready'" in host,
        "host readiness must include a completed WebView load",
    )

    require(flow.get("schemaVersion") == 1, "flow schemaVersion must remain explicit")
    require("assertAbsent" in flow_text, "flow must prove the target was not preinstalled")
    required_ids = [
        "e2e.miniapp.result.{{pluginId}}.registry",
        "e2e.miniapp.install.{{pluginId}}",
        "e2e.miniapp.result.{{pluginId}}.installed",
        "e2e.miniapp.chat.{{pluginId}}.installed",
        "e2e.miniapp.open.{{pluginId}}",
        "e2e.miniapp.host.{{pluginId}}.ready",
    ]
    for identifier in required_ids:
        require(identifier in flow_text, f"flow is missing exact locator {identifier}")
    require(
        "BEGINSWITH" not in flow_text and "ENDSWITH" not in flow_text,
        "target identity locators must not be fuzzy",
    )

    print("iOS MiniApp E2E architecture guard: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
