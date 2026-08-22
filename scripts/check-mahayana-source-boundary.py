#!/usr/bin/env python3
"""Fail CI when vendor implementation types leak into Mahayana-owned crates."""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAHAYANA = ROOT / "third_party" / "mahayana" / "mahayana-rs"
SOURCE_LOCK = MAHAYANA / "SOURCES.lock"

PRODUCT_CRATES = (
    "mahayana-core",
    "mahayana-agent",
    "mahayana-conversation",
    "mahayana-runtime",
    "mahayana-tool-host",
    "mahayana-kernel",
    "mahayana-orchestrator",
    "mahayana-workspace-engine",
    "mahayana-model",
    "mahayana-mcp-runtime",
    "mahayana-native-agent",
    "mahayana-native-engine",
    "mahayana-computer",
    "mahayana-platform-core",
    "mahayana-plugin-runtime",
    "mahayana-js-runtime",
)

FORBIDDEN_SOURCE_PATTERNS = (
    re.compile(r"\buse\s+codex_[A-Za-z0-9_:]*"),
    re.compile(r"\bextern\s+crate\s+codex_[A-Za-z0-9_]*"),
    re.compile(r"\buse\s+xai_[A-Za-z0-9_:]*"),
    re.compile(r"\bextern\s+crate\s+xai_[A-Za-z0-9_]*"),
)

FORBIDDEN_MANIFEST_PATTERNS = (
    re.compile(r"^\s*codex-[A-Za-z0-9_-]+\s*=", re.MULTILINE),
    re.compile(r"^\s*xai-[A-Za-z0-9_-]+\s*=", re.MULTILINE),
)

REQUIRED_LOCK_VALUES = (
    "repository=https://github.com/openai/codex.git",
    "repository=https://github.com/xai-org/grok-build.git",
    "license=Apache-2.0",
    "canonical_agent_provider=mahayana-agent",
    "canonical_agent_conversation=mahayana-ai:agent:assistant",
)


def fail(message: str) -> None:
    print(f"mahayana-source-boundary: {message}", file=sys.stderr)
    raise SystemExit(1)


def check_source_lock() -> None:
    if not SOURCE_LOCK.is_file():
        fail(f"missing provenance lock: {SOURCE_LOCK.relative_to(ROOT)}")
    text = SOURCE_LOCK.read_text(encoding="utf-8")
    for value in REQUIRED_LOCK_VALUES:
        if value not in text:
            fail(f"SOURCES.lock missing required value: {value}")
    commits = re.findall(r"reviewed_commit=([0-9a-f]+)", text)
    if len(commits) < 2 or any(len(commit) != 40 for commit in commits):
        fail("SOURCES.lock must pin full 40-character reviewed commits")


def check_product_crate(crate: str) -> list[str]:
    crate_root = MAHAYANA / crate
    if not crate_root.is_dir():
        return [f"missing product crate: {crate}"]
    violations: list[str] = []
    manifest = crate_root / "Cargo.toml"
    if manifest.is_file():
        text = manifest.read_text(encoding="utf-8")
        for pattern in FORBIDDEN_MANIFEST_PATTERNS:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                violations.append(
                    f"{manifest.relative_to(ROOT)}:{line}: vendor dependency belongs in an adapter"
                )
    src = crate_root / "src"
    if src.is_dir():
        for path in sorted(src.rglob("*.rs")):
            text = path.read_text(encoding="utf-8")
            for pattern in FORBIDDEN_SOURCE_PATTERNS:
                for match in pattern.finditer(text):
                    line = text.count("\n", 0, match.start()) + 1
                    violations.append(
                        f"{path.relative_to(ROOT)}:{line}: vendor type import belongs in an adapter"
                    )
    return violations


def check_adapter_exists() -> None:
    codex_adapter = MAHAYANA / "mahayana-agent-codex"
    if not codex_adapter.is_dir():
        fail("expected Codex compatibility adapter boundary is missing")
    implementation = codex_adapter / "src" / "implementation.rs"
    if not implementation.is_file():
        fail("Codex adapter implementation boundary is missing")


def main() -> None:
    check_source_lock()
    check_adapter_exists()
    violations: list[str] = []
    for crate in PRODUCT_CRATES:
        violations.extend(check_product_crate(crate))
    if violations:
        print("Mahayana vendor-boundary violations:", file=sys.stderr)
        for violation in violations:
            print(f"- {violation}", file=sys.stderr)
        raise SystemExit(1)
    print(
        "Mahayana source boundary OK: product crates are provider-neutral; "
        "vendor implementation imports remain adapter-only."
    )


if __name__ == "__main__":
    main()
