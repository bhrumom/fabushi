#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "contracts/automation/grok-bot-electron-migration.json"


def fail(message: str) -> None:
    print(f"Grok Bot Electron migration gate: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: str | Path) -> str:
    target = ROOT / path if isinstance(path, str) else path
    if not target.is_file():
        fail(f"missing required file: {target.relative_to(ROOT)}")
    return target.read_text(encoding="utf-8")




def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def assert_exported_symbols(relative: str, required_exports: list[str]) -> None:
    text = read(relative)
    missing = [
        name
        for name in required_exports
        if re.search(rf"\bexport\s+(?:async\s+)?(?:const|function|class|interface|type)\s+{re.escape(name)}\b", text) is None
    ]
    if missing:
        fail(f"adapted recovered module {relative} lost Grok exports: {', '.join(missing)}")

def resolve_relative_import(source: Path, specifier: str) -> Path | None:
    if not specifier.startswith("."):
        return None
    base = source.parent / specifier
    candidates: list[Path]
    if base.suffix:
        candidates = [base]
    else:
        candidates = [Path(f"{base}{suffix}") for suffix in (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".css")]
        candidates.extend(base / f"index{suffix}" for suffix in (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"))
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    return None


def import_graph(entry: Path) -> set[Path]:
    pattern = re.compile(
        r"(?:import|export)\s+(?:[^'\"]*?\s+from\s+)?['\"]([^'\"]+)['\"]|import\(['\"]([^'\"]+)['\"]\)"
    )
    seen: set[Path] = set()
    stack = [entry.resolve()]
    while stack:
        current = stack.pop()
        if current in seen or not current.is_file():
            continue
        seen.add(current)
        if current.suffix not in {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"}:
            continue
        text = current.read_text(encoding="utf-8")
        for match in pattern.finditer(text):
            specifier = match.group(1) or match.group(2)
            resolved = resolve_relative_import(current, specifier)
            if resolved is not None:
                stack.append(resolved)
    return seen


def feature_command_names(protocol_text: str) -> set[str]:
    marker = "pub enum FeatureCommand"
    start = protocol_text.find(marker)
    if start < 0:
        fail("FeatureCommand enum not found")
    end = protocol_text.find("pub enum HostEvent", start)
    if end < 0:
        end = len(protocol_text)
    return set(re.findall(r'#\[serde\(rename = "([^"]+)"\)\]', protocol_text[start:end]))


def main() -> None:
    contract = json.loads(read(CONTRACT_PATH))
    electron = contract["electron"]
    source = contract["source"]
    historical = contract["historicalTauri"]

    # The four standalone utilities were directly copied from Grok Bot 0.16.0.
    # Keep them byte-for-byte stable unless the provenance ledger is deliberately updated.
    for module in source["directReuseModules"]:
        actual = sha256_text(read(module["file"]))
        if actual != module["sha256"]:
            fail(
                f"direct Grok source drifted: {module['file']} "
                f"(expected {module['sha256']}, got {actual})"
            )

    # Adapted files keep browser-safe imports, but their original Grok behaviors must remain exported.
    for module in source["adaptedRecoveredModules"]:
        assert_exported_symbols(module["file"], module["requiredExports"])

    historical_reachable = set(historical["requiredReachableFiles"])
    declared_reachable = set(electron["requiredReachableFiles"])
    undeclared = sorted(historical_reachable - declared_reachable)
    if undeclared:
        fail("historically migrated Tauri modules are not declared Electron requirements: " + ", ".join(undeclared))

    for relative in historical["preservedCompatibilityFiles"] + historical["mobileOnlyFiles"]:
        if not (ROOT / relative).is_file():
            fail(f"historically migrated compatibility/mobile source disappeared: {relative}")

    entry = ROOT / electron["entry"]
    entry_text = read(entry)
    if "HostClient" not in entry_text or "<HostClient />" not in entry_text:
        fail("Electron entry does not directly render the shared Tauri/Grok HostClient")
    forbidden_shell = ("PluginRuntimeApp", "desktop-mode-switch", "open-plugin-runtime", "open-agent-host")
    for token in forbidden_shell:
        if token in entry_text:
            fail(f"second desktop UI shell returned to Electron entry: {token}")

    reachable = import_graph(entry)
    missing_reachable: list[str] = []
    for relative in electron["requiredReachableFiles"]:
        path = (ROOT / relative).resolve()
        if not path.is_file():
            missing_reachable.append(f"{relative} (missing)")
        elif path not in reachable:
            missing_reachable.append(f"{relative} (not reachable from Electron entry)")
    if missing_reachable:
        fail("historically migrated Grok modules are outside the Electron bundle:\n  - " + "\n  - ".join(missing_reachable))

    for relative in electron["requiredExistingFiles"]:
        if not (ROOT / relative).is_file():
            fail(f"historically migrated Grok source disappeared: {relative}")

    host_client = read(electron["sharedHostClient"])
    if re.search(r"feature_host_[a-z_]", host_client):
        fail("shared HostClient contains a Tauri-only command instead of the transport abstraction")

    protocol = read("third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs")
    commands = feature_command_names(protocol)
    missing_commands = [name for name in electron["requiredFeatureCommands"] if name not in commands]
    if missing_commands:
        fail("Grok-derived FeatureCommands missing from shared Rust protocol: " + ", ".join(missing_commands))

    feature_manifest = read("third_party/mahayana/mahayana-rs/mahayana-feature-host/Cargo.toml")
    if "mahayana-computer.workspace = true" not in feature_manifest:
        fail("desktop computer-use port is no longer wired into FeatureHost")

    main_process = read("desktop/electron/main.cjs")
    preload = read("desktop/electron/preload.cjs")
    app_host = read("third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs")
    for method in electron["requiredHostMethods"]:
        for label, text in (("Electron main", main_process), ("Electron preload", preload), ("Rust app host", app_host)):
            if method not in text:
                fail(f"{label} is missing migrated host method {method}")
    for channel in electron["requiredNativeBridges"]:
        if channel not in main_process or channel not in preload:
            fail(f"Electron native bridge parity is missing {channel}")

    mock_transport = read("frontend/apps/web/src/lib/mahayana-host/mock-transport.ts")
    priority = re.compile(
        r"isElectronMahayanaHostAvailable\(\)\s*\?\s*new ElectronMahayanaHostTransport\(\)"
        r"[\s\S]{0,240}?isTauriMahayanaHostAvailable\(\)\s*\?\s*new TauriMahayanaHostTransport\(\)"
    )
    if priority.search(mock_transport) is None:
        fail("shared Host transport must prefer Electron before the preserved Tauri compatibility bridge")

    recovery = source["recovery"]
    print(
        "Grok Bot Electron migration coverage: "
        f"{len(electron['requiredReachableFiles'])} bundle modules reachable, "
        f"{len(historical['requiredReachableFiles'])} historical Tauri/Grok modules protected, "
        f"{len(electron['requiredFeatureCommands'])} Grok-derived commands present, "
        f"{recovery['exactFirstPartyFiles']} exact 0.16.0 source-map files inventoried"
    )
    print(
        "Mobile remote-control client files remain intentionally mobile-only: "
        + ", ".join(electron["mobileOnlyFiles"])
    )


if __name__ == "__main__":
    main()
