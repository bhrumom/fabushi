#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTERNAL = ROOT / ".agents/plugins/marketplace.json"
PUBLIC = ROOT / "frontend/apps/web/public/.well-known/mahayana/marketplace.json"
PLUGIN_ROOT = ROOT / ".agents/plugins/plugins"
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
SUPPORTED_PLATFORMS = {"cli", "desktop", "mobile", "web"}


def load(path: Path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def searchable_terms(plugin: dict, internal: dict) -> list[str]:
    values = [
        plugin["id"],
        plugin["title"],
        plugin.get("description", ""),
        internal.get("category", ""),
        *plugin.get("aliases", []),
        *plugin.get("keywords", []),
    ]
    terms: list[str] = []
    for value in values:
        value = str(value).strip()
        if value and value not in terms:
            terms.append(value)
    return terms


def build_plan() -> dict:
    internal = load(INTERNAL)
    public = load(PUBLIC)
    if internal.get("schemaVersion") != 1:
        raise SystemExit("internal marketplace schemaVersion must be 1")
    if public.get("schemaVersion") != 1 or public.get("protocol") != "mahayana.plugin-marketplace.v1":
        raise SystemExit("public marketplace must use mahayana.plugin-marketplace.v1 schema 1")

    internal_by_id = {item["name"]: item for item in internal.get("plugins", [])}
    public_by_id = {item["id"]: item for item in public.get("plugins", [])}
    disk_ids = {path.name for path in PLUGIN_ROOT.iterdir() if path.is_dir()}
    if set(internal_by_id) != set(public_by_id) or set(public_by_id) != disk_ids:
        raise SystemExit("official plugin source, internal catalog, and public catalog IDs must match exactly")

    entries = []
    for plugin_id in sorted(public_by_id):
        if not ID_RE.fullmatch(plugin_id):
            raise SystemExit(f"invalid normalized plugin ID: {plugin_id}")
        public_item = public_by_id[plugin_id]
        internal_item = internal_by_id[plugin_id]
        platforms = public_item.get("platforms", [])
        if not platforms or any(platform not in SUPPORTED_PLATFORMS for platform in platforms):
            raise SystemExit(f"{plugin_id}: invalid supported platforms")
        if len(platforms) != len(set(platforms)):
            raise SystemExit(f"{plugin_id}: duplicate platforms")
        if public_item.get("version") != internal_item.get("version"):
            raise SystemExit(f"{plugin_id}: public/internal version mismatch")
        category = str(public_item.get("category") or internal_item.get("category") or "Other").strip()
        aliases = public_item.get("aliases", [])
        keywords = public_item.get("keywords", [])
        if not isinstance(aliases, list) or not all(isinstance(value, str) and value.strip() for value in aliases):
            raise SystemExit(f"{plugin_id}: aliases must be non-empty strings")
        if not isinstance(keywords, list) or not all(isinstance(value, str) and value.strip() for value in keywords):
            raise SystemExit(f"{plugin_id}: keywords must be non-empty strings")
        entries.append(
            {
                "pluginId": plugin_id,
                "version": public_item["version"],
                "displayName": public_item["title"],
                "description": public_item.get("description", ""),
                "category": category,
                "aliases": aliases,
                "keywords": keywords,
                "searchTerms": searchable_terms(public_item, internal_item),
                "platforms": platforms,
                "pluginPath": f".agents/plugins/plugins/{plugin_id}",
                "homepage": public_item.get("homepage"),
            }
        )

    return {
        "schemaVersion": 1,
        "protocol": "fabushi.app-registry-publication-plan.v1",
        "source": str(PUBLIC.relative_to(ROOT)),
        "count": len(entries),
        "apps": entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the official searchable App Registry publication plan")
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()
    plan = build_plan()
    print(json.dumps(plan, ensure_ascii=False, indent=2 if args.pretty else None, sort_keys=args.pretty))


if __name__ == "__main__":
    main()
