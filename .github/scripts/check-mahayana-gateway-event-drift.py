#!/usr/bin/env python3
"""Fail when the Rust and TypeScript Mahayana gateway event catalogs drift."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUST = ROOT / "third_party/mahayana/mahayana-rs/mahayana-gateway-protocol/src/lib.rs"
TYPESCRIPT = ROOT / "frontend/apps/web/src/lib/mahayana-host/gateway-events.ts"


def extract_array(source: str, marker: str, closing: str) -> list[str]:
    start = source.find(marker)
    if start < 0:
        raise SystemExit(f"missing event catalog marker: {marker}")
    start += len(marker)
    end = source.find(closing, start)
    if end < 0:
        raise SystemExit(f"unterminated event catalog after: {marker}")
    block = source[start:end]
    return re.findall(r"['\"]([a-z0-9_.-]+)['\"]", block)


rust_names = extract_array(
    RUST.read_text(encoding="utf-8"),
    "pub const GATEWAY_EVENT_NAMES: &[&str] = &[",
    "];",
)
ts_names = extract_array(
    TYPESCRIPT.read_text(encoding="utf-8"),
    "export const MAHAYANA_GATEWAY_EVENT_NAMES = [",
    "] as const;",
)

if not rust_names:
    raise SystemExit("Rust Mahayana gateway event catalog is empty")
if len(rust_names) != len(set(rust_names)):
    raise SystemExit(f"Rust Mahayana gateway event catalog contains duplicates: {rust_names}")
if len(ts_names) != len(set(ts_names)):
    raise SystemExit(f"TypeScript Mahayana gateway event catalog contains duplicates: {ts_names}")
if rust_names != ts_names:
    raise SystemExit(
        "Mahayana gateway event catalog drift detected\n"
        f"Rust:       {rust_names}\n"
        f"TypeScript: {ts_names}"
    )

print(f"Mahayana gateway event catalogs match ({len(rust_names)} ordered events)")
