#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from marketplace_security import (
    APPROVALS,
    APPROVAL_PROTOCOL,
    INTERNAL,
    PLUGIN_ROOT,
    POLICY_VERSION,
    PUBLIC,
    audit_official_plugins,
    fail_if_rejected,
    load_json,
)


def _platforms(codex: dict[str, Any], mahayana: dict[str, Any], fallback: list[str] | None) -> list[str]:
    variants = codex.get("runtimeVariants") if isinstance(codex.get("runtimeVariants"), list) else []
    values: set[str] = set()
    for variant in variants:
        if not isinstance(variant, dict):
            continue
        for platform in variant.get("platforms", []):
            if isinstance(platform, str) and platform:
                values.add(platform)
    if not values:
        runtime = mahayana.get("runtime") if isinstance(mahayana.get("runtime"), dict) else {}
        if "cli" in runtime:
            values.update({"cli", "desktop"})
        if "wasm" in runtime:
            values.update({"mobile", "web"})
    if not values and fallback:
        values.update(str(item) for item in fallback if item)
    if not values:
        values.add("cli")
    order = ["cli", "desktop", "mobile", "web", "ios", "android", "chrome-extension"]
    return sorted(values, key=lambda value: (order.index(value) if value in order else len(order), value))


def _public_plugin(entry: dict[str, Any], audit: dict[str, Any], previous: dict[str, Any] | None) -> dict[str, Any]:
    plugin_id = entry["name"]
    plugin_dir = PLUGIN_ROOT / plugin_id
    codex = load_json(plugin_dir / ".codex-plugin/plugin.json")
    mahayana = load_json(plugin_dir / ".mahayana/plugin.json")
    interface = codex.get("interface") if isinstance(codex.get("interface"), dict) else {}
    homepage = codex.get("homepage") or interface.get("websiteURL") or (previous or {}).get("homepage")
    if not homepage:
        homepage = f"https://fabushi.ombhrum.com/miniapps/{plugin_id}/"
    if not str(homepage).endswith("/") and str(homepage).startswith("https://fabushi.ombhrum.com/miniapps/"):
        homepage = f"{homepage}/"
    return {
        "id": plugin_id,
        "version": entry["version"],
        "title": interface.get("displayName") or (previous or {}).get("title") or plugin_id,
        "description": interface.get("shortDescription") or codex.get("description") or (previous or {}).get("description") or plugin_id,
        "homepage": homepage,
        "platforms": _platforms(codex, mahayana, (previous or {}).get("platforms")),
        "audit": {
            "protocol": "fabushi.marketplace.audit.v1",
            "policyVersion": POLICY_VERSION,
            "decision": "approved",
            "digest": audit["digest"],
        },
    }


def generate() -> tuple[dict[str, Any], dict[str, Any]]:
    report = audit_official_plugins(source_sha="catalog-generation")
    fail_if_rejected(report)
    audit_by_id = {item["id"]: item for item in report["plugins"]}
    internal = load_json(INTERNAL)
    current_public = load_json(PUBLIC)
    previous_by_id = {
        item.get("id"): item for item in current_public.get("plugins", []) if isinstance(item, dict) and item.get("id")
    }

    plugins = []
    approvals = []
    for entry in internal["plugins"]:
        plugin_id = entry["name"]
        audit = audit_by_id[plugin_id]
        plugins.append(_public_plugin(entry, audit, previous_by_id.get(plugin_id)))
        approvals.append({
            "id": plugin_id,
            "version": entry["version"],
            "digest": audit["digest"],
            "decision": "approved",
            "policyVersion": POLICY_VERSION,
        })

    public = {key: value for key, value in current_public.items() if key != "plugins"}
    public["plugins"] = plugins
    ledger = {
        "schemaVersion": 1,
        "protocol": APPROVAL_PROTOCOL,
        "policyVersion": POLICY_VERSION,
        "plugins": approvals,
    }
    return public, ledger


def _render(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the approved Fabushi public marketplace catalog")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()

    public, ledger = generate()
    rendered_public = _render(public)
    rendered_ledger = _render(ledger)
    if args.write:
        PUBLIC.write_text(rendered_public, encoding="utf-8")
        APPROVALS.write_text(rendered_ledger, encoding="utf-8")
        print(f"generated approved public marketplace: {len(public['plugins'])} plugins")
        return 0

    if not APPROVALS.exists():
        print("marketplace approval ledger is not initialized yet; canonical-main auto-publish must create it")
        return 0
    failures = []
    if PUBLIC.read_text(encoding="utf-8") != rendered_public:
        failures.append(str(PUBLIC.relative_to(PUBLIC.parents[4])))
    if APPROVALS.read_text(encoding="utf-8") != rendered_ledger:
        failures.append(str(APPROVALS.relative_to(APPROVALS.parents[4])))
    if failures:
        raise SystemExit("generated marketplace files are stale: " + ", ".join(failures))
    print(f"approved public marketplace is reproducible: {len(public['plugins'])} plugins")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
