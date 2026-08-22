#!/usr/bin/env python3
"""Phase 2: shrink worker_api.rs and retire leaderboard marketing remnants.

The Rust extraction remains semantics-preserving through include! seams. The
follow-up phase will promote those seams into explicit domain modules after this
exact split is proven by native tests and the wasm32 production build.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKER = ROOT / "third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api.rs"
PARTS = WORKER.parent / "worker_api_parts"
GUARD = ROOT / "fabushi/web/tests/platform-control-plane.test.js"
HOME = ROOT / "frontend/apps/web/src/app/page.tsx"
RELEASES = ROOT / "frontend/apps/web/src/lib/official-site-releases.ts"
EXPERIENCE = ROOT / "frontend/packages/shared/src/app-experience.ts"

SPLITS = [
    ("ai_usage.inc.rs", "async fn ai_usage_status", "async fn marketplace_plugins"),
    ("marketplace.inc.rs", "async fn marketplace_plugins", "async fn wallet_balance"),
    ("commerce.inc.rs", "async fn wallet_balance", "async fn current_usage_status"),
    ("ai_usage_support.inc.rs", "async fn current_usage_status", "async fn lookup_login_user"),
    ("account_support.inc.rs", "async fn lookup_login_user", "fn marketplace_asset_url"),
]


def extract(source: str, filename: str, start: str, end: str) -> tuple[str, str]:
    include = f'include!("worker_api_parts/{filename}");'
    if include in source:
        return source, ""
    start_pos = source.find(start)
    if start_pos < 0 or source.find(start, start_pos + len(start)) >= 0:
        raise SystemExit(f"missing or ambiguous start marker {start!r}")
    end_pos = source.find(end, start_pos)
    if end_pos < 0 or end_pos <= start_pos:
        raise SystemExit(f"missing end marker {end!r} after {start!r}")
    block = source[start_pos:end_pos].rstrip() + "\n"
    if len(block.encode()) < 1000:
        raise SystemExit(f"refusing suspiciously small extraction for {filename}")
    replacement = (
        "// Semantics-preserving extraction; phase 3 promotes this seam to a Rust module.\n"
        f"{include}\n\n"
    )
    return source[:start_pos] + replacement + source[end_pos:], block


def remove_list_object(text: str, marker: str) -> str:
    marker_pos = text.find(marker)
    if marker_pos < 0:
        return text
    start = text.rfind("\n  {", 0, marker_pos)
    end = text.find("\n  },", marker_pos)
    if start < 0 or end < 0:
        raise SystemExit(f"could not isolate list object containing {marker!r}")
    return text[:start] + text[end + len("\n  },"):]


def remove_exported_const_block(text: str, name: str) -> str:
    start_marker = f"export const {name} = ["
    start = text.find(start_marker)
    if start < 0:
        return text
    end = text.find("] as const;", start)
    if end < 0:
        raise SystemExit(f"unterminated exported const {name}")
    end += len("] as const;")
    while end < len(text) and text[end] == "\n":
        end += 1
    return text[:start] + text[end:]


def clean_marketing() -> None:
    home = HOME.read_text(encoding="utf-8")
    home = home.replace('  "global-ranking",\n', "")
    home = home.replace('  "global-donation-leaderboard",\n', "")
    home = remove_list_object(home, 'screenshot: "global-ranking"')
    home = remove_list_object(home, 'screenshot: "global-donation-leaderboard"')
    if "global-ranking" in home or "global-donation-leaderboard" in home or "Leaderboard" in home:
        raise SystemExit("retired leaderboard screenshots remain on the official homepage")
    HOME.write_text(home, encoding="utf-8")

    releases = RELEASES.read_text(encoding="utf-8")
    releases = "\n".join(
        line
        for line in releases.splitlines()
        if '"global-ranking"' not in line and '"global-donation-leaderboard"' not in line
    ) + "\n"
    if "global-ranking" in releases or "global-donation-leaderboard" in releases:
        raise SystemExit("retired leaderboard screenshots remain in release normalization")
    RELEASES.write_text(releases, encoding="utf-8")

    experience = EXPERIENCE.read_text(encoding="utf-8")
    experience = remove_list_object(experience, 'id: "leaderboard"')
    experience = remove_exported_const_block(experience, "leaderboardPreview")
    experience = experience.replace("计时、念诵计数、回向和榜单入口", "计时、念诵计数、回向和个人记录")
    if "leaderboard" in experience.lower() or "榜单入口" in experience:
        raise SystemExit("retired leaderboard product data remains in shared app experience")
    EXPERIENCE.write_text(experience, encoding="utf-8")

    for relative in [
        "frontend/apps/web/public/product/global-ranking.png",
        "frontend/apps/web/public/product/global-donation-leaderboard.png",
    ]:
        asset = ROOT / relative
        if asset.exists():
            asset.unlink()
            print(f"removed retired asset {relative}")


def tighten_guard() -> None:
    guard = GUARD.read_text(encoding="utf-8")
    old = "rustWorkerBytes <= 244255"
    new = "rustWorkerBytes <= 65000"
    if old in guard:
        guard = guard.replace(old, new, 1)
    elif new not in guard:
        raise SystemExit("unexpected worker_api.rs architecture budget")

    anchor = "const platformWrangler = read('../../third_party/mahayana/mahayana-rs/mahayana-platform-worker/wrangler.toml');"
    checks = """const marketingSources = [
  read('../../frontend/apps/web/src/app/page.tsx'),
  read('../../frontend/apps/web/src/lib/official-site-releases.ts'),
  read('../../frontend/packages/shared/src/app-experience.ts'),
].join('\\n');
assert.doesNotMatch(marketingSources, /leaderboard|global-ranking/i, 'retired leaderboard must not return to active product or marketing data');

"""
    if "const marketingSources = [" not in guard:
        if anchor not in guard:
            raise SystemExit("architecture guard anchor moved unexpectedly")
        guard = guard.replace(anchor, checks + anchor, 1)
    GUARD.write_text(guard, encoding="utf-8")


def main() -> None:
    source = WORKER.read_text(encoding="utf-8")
    before = len(source.encode())
    PARTS.mkdir(parents=True, exist_ok=True)
    changed = False

    for filename, start, end in SPLITS:
        source, block = extract(source, filename, start, end)
        if not block:
            continue
        destination = PARTS / filename
        if destination.exists():
            raise SystemExit(f"refusing to overwrite existing split file {destination}")
        destination.write_text(block, encoding="utf-8")
        changed = True
        print(f"extracted {filename}: {len(block.encode())} bytes")

    if changed:
        WORKER.write_text(source, encoding="utf-8")
    after = len(WORKER.read_bytes())
    if after > 65_000:
        raise SystemExit(f"worker_api.rs phase-2 budget not met: {after} bytes")
    if changed and after >= before:
        raise SystemExit(f"worker_api.rs did not shrink: {before} -> {after}")

    clean_marketing()
    tighten_guard()

    combined = WORKER.read_text(encoding="utf-8") + "\n" + "\n".join(
        path.read_text(encoding="utf-8") for path in sorted(PARTS.glob("*.inc.rs"))
    )
    for marker in [
        "async fn ai_usage_status",
        "async fn marketplace_plugins",
        "async fn wallet_balance",
        "async fn current_usage_status",
        "async fn lookup_login_user",
        "fn marketplace_asset_url",
    ]:
        if combined.count(marker) != 1:
            raise SystemExit(f"domain marker {marker!r} must exist exactly once")

    print(f"worker_api.rs phase-2 size: {before} -> {after} bytes")


if __name__ == "__main__":
    main()
