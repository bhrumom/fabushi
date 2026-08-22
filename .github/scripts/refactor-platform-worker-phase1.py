#!/usr/bin/env python3
"""One-shot structural split for the Mahayana Platform Worker God file.

The first phase is intentionally semantics-preserving: extracted Rust items are
re-inserted with include! so they remain in worker_api's module scope. This lets
CI prove the exact refactor before later phases tighten module visibility.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api.rs"
PARTS = SOURCE.parent / "worker_api_parts"

SPLITS = [
    (
        "remote_types.inc.rs",
        "const REMOTE_PAIRING_SECONDS",
        "#[event(fetch, respond_with_errors)]",
    ),
    (
        "remote_control.inc.rs",
        "fn remote_secret_hash",
        "async fn listener_register",
    ),
    (
        "listener_relay.inc.rs",
        "async fn listener_register",
        "async fn password_session_value",
    ),
    (
        "account_browser_auth.inc.rs",
        "async fn password_session_value",
        "async fn ai_usage_status",
    ),
]


def split_block(source: str, filename: str, start: str, end: str) -> tuple[str, str]:
    include = f'include!("worker_api_parts/{filename}");'
    if include in source:
        return source, ""
    start_pos = source.find(start)
    if start_pos < 0:
        raise SystemExit(f"missing refactor start marker: {start!r}")
    if source.find(start, start_pos + len(start)) >= 0:
        raise SystemExit(f"ambiguous refactor start marker: {start!r}")
    end_pos = source.find(end, start_pos)
    if end_pos < 0:
        raise SystemExit(f"missing refactor end marker: {end!r}")
    if end_pos <= start_pos:
        raise SystemExit(f"invalid marker order for {filename}")

    block = source[start_pos:end_pos].rstrip() + "\n"
    if len(block) < 500:
        raise SystemExit(f"refusing suspiciously small extraction for {filename}: {len(block)} bytes")
    replacement = (
        f"// Structurally extracted from worker_api.rs. Keep this include as a\n"
        f"// compatibility seam until this domain is promoted to an explicit module.\n"
        f"{include}\n\n"
    )
    return source[:start_pos] + replacement + source[end_pos:], block


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    original_size = len(source.encode())
    PARTS.mkdir(parents=True, exist_ok=True)
    changed = False

    for filename, start, end in SPLITS:
        source, block = split_block(source, filename, start, end)
        if not block:
            continue
        destination = PARTS / filename
        if destination.exists():
            raise SystemExit(f"refusing to overwrite pre-existing split file: {destination}")
        destination.write_text(block, encoding="utf-8")
        changed = True
        print(f"extracted {filename}: {len(block.encode())} bytes")

    if not changed:
        print("worker_api.rs phase-1 split already applied")
        return

    SOURCE.write_text(source, encoding="utf-8")
    new_size = len(source.encode())
    if new_size >= original_size:
        raise SystemExit(f"worker_api.rs did not shrink: {original_size} -> {new_size}")
    if new_size > 155_000:
        raise SystemExit(f"worker_api.rs phase-1 budget not met: {new_size} bytes")

    combined = source + "\n" + "\n".join(
        (PARTS / filename).read_text(encoding="utf-8") for filename, *_ in SPLITS
    )
    for marker in [
        "fn remote_secret_hash",
        "async fn listener_register",
        "async fn password_session_value",
        "async fn ai_usage_status",
    ]:
        expected = 1
        actual = combined.count(marker)
        if actual != expected:
            raise SystemExit(f"marker {marker!r} expected {expected}, found {actual}")

    print(f"worker_api.rs phase-1 split: {original_size} -> {new_size} bytes")


if __name__ == "__main__":
    main()
