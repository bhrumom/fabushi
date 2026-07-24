#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTERNAL = ROOT / '.agents/plugins/marketplace.json'
PUBLIC = ROOT / 'frontend/apps/web/public/.well-known/mahayana/marketplace.json'
PLUGIN_ROOT = ROOT / '.agents/plugins/plugins'


def load(path: Path):
    with path.open(encoding='utf-8') as f:
        return json.load(f)


def main():
    internal = load(INTERNAL)
    public = load(PUBLIC)
    assert internal['schemaVersion'] == 1
    assert public['schemaVersion'] == 1
    assert public['protocol'] == 'mahayana.plugin-marketplace.v1'
    internal_ids = {p['name'] for p in internal['plugins']}
    public_ids = {p['id'] for p in public['plugins']}
    disk_ids = {p.name for p in PLUGIN_ROOT.iterdir() if p.is_dir()}
    assert internal_ids == public_ids == disk_ids
    for plugin in internal['plugins']:
        path = PLUGIN_ROOT / plugin['name']
        codex = load(path / '.codex-plugin/plugin.json')
        mahayana = load(path / '.mahayana/plugin.json')
        assert codex['name'] == plugin['name']
        assert codex['version'] == plugin['version']
        assert mahayana['schemaVersion'] == 1
        assert (path / '.mcp.json').exists()
    print(f'official marketplace contract valid: {len(internal_ids)} plugins')


if __name__ == '__main__':
    main()
