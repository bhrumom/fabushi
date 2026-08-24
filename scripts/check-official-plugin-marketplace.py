#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTERNAL = ROOT / '.agents/plugins/marketplace.json'
PUBLIC = ROOT / 'frontend/apps/web/public/.well-known/mahayana/marketplace.json'
PLUGIN_ROOT = ROOT / '.agents/plugins/plugins'
PLAN_SCRIPT = ROOT / 'scripts/official-app-registry-plan.py'
NORMALIZED_ID = re.compile(r'^[a-z0-9][a-z0-9-]*$')
SUPPORTED_PLATFORMS = {'cli', 'desktop', 'mobile', 'web'}


def load(path: Path):
    with path.open(encoding='utf-8') as f:
        return json.load(f)


def load_plan_module():
    spec = importlib.util.spec_from_file_location('official_app_registry_plan', PLAN_SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    internal = load(INTERNAL)
    public = load(PUBLIC)
    assert internal['schemaVersion'] == 1
    assert public['schemaVersion'] == 1
    assert public['protocol'] == 'mahayana.plugin-marketplace.v1'
    assert public.get('discovery', {}).get('registry') == 'cloud-marketplace'
    assert public.get('discovery', {}).get('searchable') is True

    internal_ids = {p['name'] for p in internal['plugins']}
    public_ids = {p['id'] for p in public['plugins']}
    assert len(internal_ids) == len(internal['plugins']), 'internal plugin IDs must be unique'
    assert len(public_ids) == len(public['plugins']), 'public plugin IDs must be unique'
    public_plugins = {p['id']: p for p in public['plugins']}
    disk_ids = {p.name for p in PLUGIN_ROOT.iterdir() if p.is_dir()}
    assert internal_ids == public_ids == disk_ids

    for plugin in internal['plugins']:
        plugin_id = plugin['name']
        assert NORMALIZED_ID.fullmatch(plugin_id), f'invalid normalized plugin id: {plugin_id}'
        path = PLUGIN_ROOT / plugin_id
        codex = load(path / '.codex-plugin/plugin.json')
        mahayana = load(path / '.mahayana/plugin.json')
        public_plugin = public_plugins[plugin_id]
        assert plugin['source'] == {
            'source': 'local',
            'path': f"./plugins/{plugin_id}",
        }
        assert codex['name'] == plugin_id
        assert codex['version'] == plugin['version']
        assert public_plugin['version'] == plugin['version']
        assert mahayana['schemaVersion'] == 1
        assert (path / '.mcp.json').exists()
        assert public_plugin.get('title', '').strip(), f'{plugin_id}: title required'
        assert public_plugin.get('description', '').strip(), f'{plugin_id}: description required'
        assert public_plugin.get('category', '').strip(), f'{plugin_id}: category required'
        assert isinstance(public_plugin.get('aliases'), list), f'{plugin_id}: aliases must be a list'
        assert isinstance(public_plugin.get('keywords'), list), f'{plugin_id}: keywords must be a list'
        assert all(isinstance(value, str) and value.strip() for value in public_plugin['aliases'])
        assert all(isinstance(value, str) and value.strip() for value in public_plugin['keywords'])
        platforms = public_plugin.get('platforms', [])
        assert platforms and len(platforms) == len(set(platforms)), f'{plugin_id}: platforms invalid'
        assert set(platforms) <= SUPPORTED_PLATFORMS, f'{plugin_id}: unsupported platform'

    plan = load_plan_module().build_plan()
    assert plan['protocol'] == 'fabushi.app-registry-publication-plan.v1'
    assert plan['count'] == len(public_ids)
    assert {app['pluginId'] for app in plan['apps']} == public_ids
    for app in plan['apps']:
        assert app['searchTerms'], f"{app['pluginId']}: search terms required"
        assert app['pluginId'] in app['searchTerms']
        assert app['displayName'] in app['searchTerms']

    print(f'official marketplace + searchable App Registry contract valid: {len(internal_ids)} apps')


if __name__ == '__main__':
    main()
