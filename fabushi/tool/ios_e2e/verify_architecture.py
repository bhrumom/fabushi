#!/usr/bin/env python3
"""Fail CI if iOS MiniApp E2E regresses to a fake-install architecture."""

from __future__ import annotations

import json
import re
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
WORKFLOW = ROOT / ".github/workflows/ios-external-miniapp-e2e.yml"
PUBSPEC = ROOT / "fabushi/pubspec.yaml"
PUBSPEC_LOCK = ROOT / "fabushi/pubspec.lock"
IOS_RUNTIME_BUILD = ROOT / "fabushi/ios/build_telegram_runtime.sh"
AUTOFIX_WORKFLOW = ROOT / ".github/workflows/ios-e2e-codex-autofix.yml"
RELEASE_GATE = ROOT / ".github/workflows/important-release-gate.yml"
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
CLI = ROOT / "third_party/mahayana/mahayana-rs/mahayana-cli/src/main.rs"
CONTROL = ROOT / "fabushi/lib/services/miniapp/mahayana_e2e_control_io.dart"
FIXTURE = ROOT / "fabushi/tool/ios_e2e/marketplace_fixture.py"
FIXTURE_PROBE = ROOT / "fabushi/tool/ios_e2e/marketplace_fixture_probe.py"
CANONICAL_PLUGIN = (
    ROOT / ".agents/plugins/plugins/global-dharma/.codex-plugin/plugin.json"
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"iOS MiniApp E2E architecture violation: {message}")


DART_DIRECTIVE_RE = re.compile(
    r"(?ms)^\s*(?:import|export|part)\s+(.*?);"
)
DART_URI_RE = re.compile(r"['\"]([^'\"]+)['\"]")


def _dart_local_targets(source: Path, lib_root: Path) -> list[Path]:
    targets: list[Path] = []
    text = source.read_text(encoding="utf-8", errors="ignore")
    for directive in DART_DIRECTIVE_RE.findall(text):
        for uri in DART_URI_RE.findall(directive):
            if uri.startswith("dart:"):
                continue
            if uri.startswith("package:global_dharma_sharing/"):
                target = lib_root / uri.split("/", 1)[1]
            elif uri.startswith("package:"):
                continue
            else:
                target = (source.parent / uri).resolve()
            if target.exists() and target.suffix == ".dart":
                targets.append(target.resolve())
    return targets


def require_no_dead_dart_sources() -> None:
    """Keep the host source tree equal to real runtime/test/tool entry closures."""
    lib_root = (ROOT / "fabushi/lib").resolve()
    roots: set[Path] = {(lib_root / "main.dart").resolve()}

    # A dormant platform module is allowed only when a test/integration/tool
    # explicitly owns it. This keeps development utilities testable without
    # letting unreferenced standalone-App code accumulate in lib/ again.
    for base in (
        ROOT / "fabushi/test",
        ROOT / "fabushi/integration_test",
        ROOT / "fabushi/tool",
    ):
        if not base.exists():
            continue
        for source in base.rglob("*.dart"):
            for target in _dart_local_targets(source.resolve(), lib_root):
                try:
                    target.relative_to(lib_root)
                except ValueError:
                    continue
                roots.add(target)

    reachable: set[Path] = set()
    queue: deque[Path] = deque(sorted(roots))
    while queue:
        source = queue.popleft().resolve()
        if source in reachable or not source.exists():
            continue
        reachable.add(source)
        for target in _dart_local_targets(source, lib_root):
            try:
                target.relative_to(lib_root)
            except ValueError:
                continue
            if target not in reachable:
                queue.append(target)

    all_sources = {path.resolve() for path in lib_root.rglob("*.dart")}
    dead = sorted(all_sources - reachable)
    require(
        not dead,
        "unreachable Dart sources must be deleted or wired/tested: "
        + ", ".join(str(path.relative_to(lib_root)) for path in dead[:20]),
    )


def main() -> int:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    pubspec = PUBSPEC.read_text(encoding="utf-8")
    pubspec_lock = PUBSPEC_LOCK.read_text(encoding="utf-8")
    ios_runtime_build = IOS_RUNTIME_BUILD.read_text(encoding="utf-8")
    autofix_workflow = AUTOFIX_WORKFLOW.read_text(encoding="utf-8")
    release_gate = RELEASE_GATE.read_text(encoding="utf-8")
    product = PRODUCT.read_text(encoding="utf-8")
    installer = INSTALLER.read_text(encoding="utf-8")
    service = MARKETPLACE_SERVICE.read_text(encoding="utf-8")
    host = HOST.read_text(encoding="utf-8")
    cli = CLI.read_text(encoding="utf-8")
    control = CONTROL.read_text(encoding="utf-8")
    fixture = FIXTURE.read_text(encoding="utf-8")
    fixture_probe = FIXTURE_PROBE.read_text(encoding="utf-8")
    canonical_plugin = json.loads(CANONICAL_PLUGIN.read_text(encoding="utf-8"))
    flow = json.loads(FLOW.read_text(encoding="utf-8"))
    flow_text = json.dumps(flow, ensure_ascii=False)

    require_no_dead_dart_sources()

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
        "TestDriver" not in cli and "test_driver_command" not in cli,
        "fake CLI test-driver endpoints are forbidden; E2E state must come from production services",
    )
    require(
        "MAHAYANA_TEST_DRIVER_ALLOW_RELEASE" not in cli,
        "release-enable escape hatches for test drivers are forbidden",
    )
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
    require(
        "marketplace_mode:" in workflow and "- fixture" in workflow and "- live" in workflow,
        "workflow_dispatch must expose explicit fixture/live Marketplace modes",
    )
    require(
        "github.event_name == 'schedule' && 'live'" in workflow,
        "scheduled L3 canaries must always use the live Marketplace",
    )
    require(
        "SIMCTL_CHILD_MAHAYANA_API_BASE_URL" in workflow,
        "the app process must receive the selected Marketplace API base URL",
    )
    require(
        "if: env.MARKETPLACE_MODE == 'fixture'" in workflow,
        "the deterministic Marketplace fixture must run only in fixture mode",
    )
    require(
        "--port 0" in workflow and "FIXTURE_MARKETPLACE_API_BASE_URL" not in workflow,
        "the deterministic fixture must use an OS-assigned loopback port rather than a fixed port",
    )
    require(
        "marketplace_fixture_probe.py" in workflow
        and "--full-contract" in workflow,
        "L1 and L2 must reuse the fixture probe and verify the full HTTP distribution contract",
    )
    require(
        "urllib.request.ProxyHandler({})" in fixture_probe,
        "fixture readiness checks must bypass ambient HTTP proxy configuration",
    )
    require(
        ".agents/plugins/plugins/global-dharma" in workflow,
        "L2 fixture bytes must be built from the canonical repository global-dharma plugin",
    )
    require(
        "- '.agents/plugins/plugins/global-dharma/**'" in workflow,
        "canonical global-dharma changes must trigger the iOS E2E workflow",
    )
    require(
        "- '.github/workflows/ios-e2e-codex-autofix.yml'" in workflow,
        "autofix policy changes must re-run the production-path iOS E2E architecture gate",
    )
    require(
        "--method marketplace.search" in workflow,
        "black-box runs must preflight the exact release through the production product client",
    )
    require(
        "LIVE_MARKETPLACE_RELEASE_MISSING" in workflow,
        "live canaries must classify a missing production release explicitly",
    )
    require(
        "fabushi.marketplace.fixture.v1" in fixture,
        "the deterministic Marketplace fixture must use a versioned protocol",
    )
    for endpoint in (
        "/v1/marketplace/plugins",
        "/releases/{version}",
        "/releases/{version}/download",
    ):
        require(endpoint in fixture, f"Marketplace fixture is missing endpoint contract {endpoint}")
    for forbidden in (
        "codexHome",
        "codex/plugins",
        "mahayana-runtime",
        "simctl",
        "install_marketplace_bundle_to_codex_home",
    ):
        require(
            forbidden not in fixture,
            f"Marketplace fixture must distribute bytes only and must not prepare app state ({forbidden})",
        )
        require(
            forbidden not in fixture_probe,
            f"Marketplace fixture probe must observe distribution only and must not prepare app state ({forbidden})",
        )
    require(
        canonical_plugin.get("name") == "global-dharma"
        and isinstance(canonical_plugin.get("version"), str)
        and bool(canonical_plugin["version"].strip()),
        "the canonical L2 fixture source must remain global-dharma with an explicit version",
    )
    require(
        any(
            isinstance(variant, dict)
            and isinstance(variant.get("platforms"), list)
            and "mobile" in variant["platforms"]
            for variant in canonical_plugin.get("runtimeVariants", [])
        ),
        "the canonical L2 fixture source must expose a mobile runtime variant",
    )
    require(
        "xcrun simctl create" in workflow
        and "xcrun simctl delete" in workflow
        and "timeout=240" in workflow,
        "each black-box run must use and clean up a bounded, isolated Simulator",
    )
    require(
        "Resolve Flutter dependencies without lock drift" in workflow
        and 'git -C "$GITHUB_WORKSPACE" diff --exit-code -- fabushi/pubspec.lock' in workflow
        and "timeout-minutes: 45" in workflow,
        "dependency resolution must reject lock drift and the post-seed iOS build must remain independently bounded",
    )
    require(
        "COCOAPODS_VERSION: 1.17.0" in workflow
        and "pod install --deployment" in workflow
        and 'diff --exit-code -- fabushi/ios/Podfile.lock' in workflow
        and "Restore CocoaPods download cache" in workflow
        and "Save CocoaPods download cache" in workflow,
        "CocoaPods must be pinned, lock-clean, and independently cached before Flutter invokes Xcode",
    )
    require(
        "Snapshot resolved dependency locks" in workflow
        and "Podfile.lock.resolved" in workflow
        and "lock-diff.patch" in workflow,
        "macOS runs must preserve the actual Pub/CocoaPods lock resolution as evidence",
    )
    require(
        "Fingerprint iOS Mahayana runtime inputs" in workflow
        and "Restore fingerprinted iOS Mahayana runtime" in workflow
        and "Seed iOS Simulator Mahayana runtime" in workflow
        and "Save fingerprinted iOS Mahayana runtime" in workflow
        and "actions/cache/restore@v4" in workflow
        and "actions/cache/save@v4" in workflow
        and "ios-mahayana-runtime-v1-" in workflow
        and "mahayana-ios-runtime-fingerprint.txt" in workflow
        and "mahayana-ios-simulator-runtime.log" in workflow
        and ("CARGO_PROFILE_DEV_DEBUG: 0" in workflow or 'CARGO_PROFILE_DEV_DEBUG: "0"' in workflow)
        and "steps.rust-toolchain.outputs.fingerprint" in workflow
        and "rustc -vV | tee artifacts/logs/rustc-version.txt" in workflow,
        "the Simulator Rust runtime must be fingerprinted, seeded through the production build script, and saved immediately",
    )
    require(
        "Verify Xcode reuses fingerprinted Mahayana runtime" in workflow
        and "Reusing fingerprinted Mahayana Rust runtime" in workflow,
        "Xcode must prove it reuses the exact prebuilt production Rust archive rather than cold-compiling inside Flutter",
    )
    require(
        "fabushi.mahayana.ios-runtime-fingerprint.v1" in ios_runtime_build
        and "--fingerprint" in ios_runtime_build
        and "third_party/mahayana/mahayana-rs" in ios_runtime_build
        and "third_party/mahayana/codex-rs" in ios_runtime_build
        and "rustc -vV" in ios_runtime_build
        and "cargo -V" in ios_runtime_build
        and "Reusing fingerprinted Mahayana Rust runtime" in ios_runtime_build
        and 'cargo "${cargo_args[@]}"' in ios_runtime_build,
        "the production iOS Rust script must content-address its real inputs and only reuse an exact fingerprint match",
    )
    require(
        "runs-on: macos-15" in workflow,
        "the iOS black-box job must use the macOS 15 runner image",
    )
    require(
        "DEVELOPER_DIR: /Applications/Xcode_16.4.app/Contents/Developer" in workflow,
        "the iOS black-box job must pin Xcode 16.4 explicitly",
    )
    require(
        'Expected Xcode 16.4, got $xcode_version' in workflow,
        "the workflow must fail fast when the selected Xcode drifts",
    )
    require("appium@3.6.0" in workflow, "Appium must be pinned to 3.6.0")
    require(
        "xcuitest@12.3.1" in workflow,
        "the XCUITest driver must be pinned to 12.3.1",
    )
    require("PLUGIN_ID: global-dharma" in workflow, "the canary plugin id must be exact")

    # The host is now a platform. Historical standalone Global Dharma media,
    # 3D, Firebase, local-ASR/LLM and background-transfer plugins must not
    # return to the host dependency graph; those capabilities belong to
    # MiniApps or optional external tools.
    legacy_host_dependencies = (
        "flutter_earth_globe",
        "flutter_gl",
        "three_dart",
        "three_dart_jsm",
        "flutter_scene",
        "flutter_scene_importer",
        "ffmpeg_kit_flutter_new_audio",
        "firebase_core",
        "firebase_auth",
        "cloud_firestore",
        "google_sign_in",
        "in_app_purchase",
        "video_player",
        "flutter_cache_manager",
        "preload_page_view",
        "flutter_local_notifications",
        "just_audio",
        "flutter_tts",
        "workmanager",
        "sherpa_onnx",
        "record",
        "audio_session",
        "llama_cpp_dart",
    )
    for dependency in legacy_host_dependencies:
        require(
            re.search(rf"(?m)^  {re.escape(dependency)}:", pubspec) is None,
            f"legacy standalone-app dependency {dependency} must not return to the host pubspec",
        )
        require(
            re.search(rf"(?m)^  {re.escape(dependency)}:.*?\n(?:    .*\n)*?    name: {re.escape(dependency)}$", pubspec_lock) is None
            and f"name: {dependency}\n" not in pubspec_lock,
            f"legacy standalone-app dependency {dependency} must not remain in pubspec.lock",
        )

    for legacy_path in (
        ROOT / "fabushi/native_libs/llama.cpp",
        ROOT / "fabushi/android/app/src/main/jniLibs",
        ROOT / "fabushi/macos/Runner/Libs",
        ROOT / "fabushi/macos/copy_llama_libs.sh",
        ROOT / "fabushi/scripts/build_android_arm64.sh",
        ROOT / "fabushi/android/app/google-services.json",
        ROOT / "fabushi/ios/Runner/GoogleService-Info.plist",
        ROOT / "fabushi/macos/Runner/GoogleService-Info.plist",
        ROOT / "fabushi/ios/Runner/Configuration.storekit",
        ROOT / "fabushi/test/unit/core/app_config_buddha_model_test.dart",
        ROOT / "fabushi/assets/images",
        ROOT / "fabushi/fonts/NotoSansSC-Bold.otf",
        ROOT / "fabushi/fonts/NotoSansSC-Regular.otf",
        ROOT / "fabushi/fonts/NotoSerifSC-Bold.otf",
        ROOT / "fabushi/fonts/NotoSerifSC-Regular.otf",
        ROOT / "fabushi/scripts/archive/build_web_exclude_models.sh",
        ROOT / "fabushi/scripts/archive/update_firebase_config.sh",
        ROOT / "fabushi/scripts/setup/setup_firebase.sh",
        ROOT / ".github/workflows/android-real-device-e2e.yml",
        ROOT / "scripts/check_home_send_flow.py",
        ROOT / "fabushi/lib/packages/flutter_earth_globe",
        ROOT / "fabushi/lib/packages/flutter_gl",
        ROOT / "fabushi/lib/packages/flutter_scene",
        ROOT / "fabushi/lib/packages/three_dart",
        ROOT / "fabushi/lib/features/video_feed",
        ROOT / "fabushi/temp_video_feed",
        ROOT / "fabushi/assets/built_in",
        ROOT / "fabushi/web/assets/built_in",
    ):
        require(
            not legacy_path.exists(),
            f"legacy standalone-app tree must stay deleted: {legacy_path.relative_to(ROOT)}",
        )

    ios_project = (ROOT / "fabushi/ios/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    android_main = (ROOT / "fabushi/android/app/src/main/kotlin/com/ombhrum/fabushi/MainActivity.kt").read_text(encoding="utf-8")
    android_app_gradle = (ROOT / "fabushi/android/app/build.gradle.kts").read_text(encoding="utf-8")
    android_settings_gradle = (ROOT / "fabushi/android/settings.gradle.kts").read_text(encoding="utf-8")
    macos_project = (ROOT / "fabushi/macos/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    for token in ("libllama", "libggml", "ggml-metal.metal", "StoreKit.framework"):
        require(
            token not in ios_project,
            f"legacy standalone native linkage {token} must not return to the iOS host",
        )
    require(
        "System.loadLibrary(\"llama\")" not in android_main
        and "System.loadLibrary(\"ggml" not in android_main,
        "Android host must not preload the removed llama/ggml runtime",
    )
    require(
        "com.google.gms.google-services" not in android_app_gradle
        and "com.google.gms.google-services" not in android_settings_gradle,
        "standalone Firebase Gradle configuration must not return to the platform host",
    )
    require(
        "Copy Llama Libraries" not in macos_project,
        "macOS host must not restore the legacy Copy Llama Libraries build phase",
    )

    ios_info = (ROOT / "fabushi/ios/Runner/Info.plist").read_text(encoding="utf-8")
    android_manifest = (ROOT / "fabushi/android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
    require(
        "FLTEnableFlutterGPU" not in ios_info
        and "EnableFlutterGPU" not in android_manifest,
        "old 3D-only FlutterGPU opt-ins must not return to the platform host",
    )
    workflow_text = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / ".github/workflows").glob("*.yml"))
    )
    require(
        "submodules: recursive" not in workflow_text
        and "git submodule update --init --recursive" not in workflow_text,
        "the repository has no gitlinks; CI must not restore recursive submodule overhead",
    )
    require(
        "flutter_scene_importer" not in workflow_text
        and "Verify Android Buddha uses flutter_scene model" not in workflow_text
        and "Verify Apple Buddha asset StoreKit product" not in workflow_text,
        "legacy 3D/StoreKit build gates must not return to CI",
    )

    require(
        "Homepage send flow regression" not in workflow_text
        and "check_home_send_flow" not in workflow_text
        and "home_send_real_device_test.dart" not in workflow_text,
        "standalone Global Dharma homepage-send CI gates must not return",
    )
    require(
        "uses: ./.github/workflows/ios-external-miniapp-e2e.yml" in release_gate
        and "marketplace_mode: live" in release_gate
        and "needs: ios-miniapp-e2e" in release_gate,
        "important releases must be gated by the live platform MiniApp E2E workflow",
    )

    generated_plugin_files = (
        ROOT / "fabushi/linux/flutter/generated_plugin_registrant.cc",
        ROOT / "fabushi/linux/flutter/generated_plugins.cmake",
        ROOT / "fabushi/windows/flutter/generated_plugin_registrant.cc",
        ROOT / "fabushi/windows/flutter/generated_plugins.cmake",
        ROOT / "fabushi/macos/Flutter/GeneratedPluginRegistrant.swift",
    )
    legacy_generated_tokens = (
        "firebase",
        "ffmpeg",
        "flutter_tts",
        "record_",
        "rive",
        "sherpa",
        "video_player",
        "just_audio",
        "workmanager",
        "in_app_purchase",
    )
    for generated in generated_plugin_files:
        generated_text = generated.read_text(encoding="utf-8")
        for token in legacy_generated_tokens:
            require(
                token not in generated_text.lower(),
                f"generated desktop plugin graph must not restore legacy plugin {token}: {generated.relative_to(ROOT)}",
            )

    native_app = (ROOT / "fabushi/lib/bootstrap/native_app.dart").read_text(encoding="utf-8")
    require(
        "FileTransferModel" not in native_app
        and "VideoFeedVisibilityNotifier" not in native_app
        and "CountrySendingModel" not in native_app,
        "the platform bootstrap must not re-register standalone Global Dharma providers",
    )
    require(
        "platform-slim-contract:" in workflow
        and "ios-dependency-contract:" in workflow
        and "Restore production-contract Rust cache" in workflow
        and "Swatinem/rust-cache@v2" in workflow
        and "Restore cached iOS E2E Runner.app" in workflow
        and "Save cached iOS E2E Runner.app" in workflow,
        "CI must keep lightweight platform/dependency gates and the content-addressed Runner.app cache",
    )

    require(
        'workflows: ["iOS External MiniApp E2E"]' in autofix_workflow
        and "github.event.workflow_run.conclusion == 'failure'" in autofix_workflow
        and "github.event.workflow_run.event == 'pull_request'" in autofix_workflow,
        "Codex autofix must only follow failed PR executions of the iOS E2E workflow",
    )
    require(
        "vars.IOS_E2E_AUTOFIX_ENABLED == 'true'" in autofix_workflow,
        "Codex autofix must require an explicit repository-level enable switch",
    )
    require(
        "openai/codex-action@52fe01ec70a42f454c9d2ebd47598f9fd6893d56" in autofix_workflow
        and 'codex-version: "0.147.0"' in autofix_workflow
        and "secrets.OPENAI_API_KEY" in autofix_workflow,
        "public-repository autofix must use the official Codex Action with a dedicated API key",
    )
    require(
        "CHATGPT_CODEX_AUTH_B64" not in autofix_workflow
        and "CHATGPT_SESSION_COOKIES_B64" not in autofix_workflow,
        "public-repository autofix must never reuse seeded ChatGPT auth/session credentials",
    )
    require(
        autofix_workflow.count("persist-credentials: false") >= 2,
        "Codex-facing and writeback checkouts must not persist GitHub credentials",
    )
    require(
        "name: Generate bounded Codex patch" in autofix_workflow
        and "name: Verify and write back Codex repair" in autofix_workflow
        and "contents: read" in autofix_workflow
        and "contents: write" in autofix_workflow,
        "Codex patch generation and privileged writeback must remain separate permission domains",
    )
    require(
        "ios-e2e-autofix.patch" in autofix_workflow
        and "git apply --check" in autofix_workflow,
        "autofix must cross the permission boundary as a reviewable patch artifact",
    )
    require(
        "priorRounds >= 2" in autofix_workflow
        and "automated Codex repair [round $REPAIR_ROUND]" in autofix_workflow,
        "automatic repair must be capped at two rounds",
    )
    require(
        "pr.head.repo.full_name === repoFullName" in autofix_workflow
        and "trustedAssociations" in autofix_workflow
        and "pr.head.sha === run.head_sha" in autofix_workflow,
        "autofix must reject forks, untrusted authors, and stale PR heads before Codex runs",
    )
    require(
        "remote_head" in autofix_workflow
        and autofix_workflow.count("EXPECTED_HEAD_SHA") >= 4,
        "privileged writeback must re-check that the PR head has not moved",
    )
    require(
        autofix_workflow.count("outside the iOS E2E repair allowlist") >= 2
        and "Re-validate protected files and repair allowlist" in autofix_workflow,
        "Codex proposal and privileged writeback must independently enforce a narrow repair-file allowlist",
    )
    for protected in (
        ".github/workflows/ios-e2e-codex-autofix.yml",
        "fabushi/tool/ios_e2e/verify_architecture.py",
        "docs/testing/ios-external-miniapp-e2e.md",
    ):
        require(
            protected in autofix_workflow,
            f"Codex autofix must protect its policy root from self-modification ({protected})",
        )

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
    appium_flow = (ROOT / "fabushi/tool/ios_e2e/appium_flow.py").read_text(encoding="utf-8")
    require(
        "report.html" in appium_flow
        and "timeline.jsonl" in appium_flow
        and '"session-failure"' in appium_flow,
        "black-box evidence must include a browsable HTML report and structured session failures",
    )
    require(
        "urllib.request.ProxyHandler({})" in appium_flow,
        "local Appium WebDriver requests must bypass ambient HTTP proxy configuration",
    )
    require(
        "opener.open('http://127.0.0.1:4723/status'" in workflow,
        "Appium readiness checks must use the no-proxy loopback opener",
    )
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
