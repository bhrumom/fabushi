#!/usr/bin/env python3
from __future__ import annotations

from marketplace_security import (
    APPROVALS,
    APPROVAL_PROTOCOL,
    INTERNAL,
    PLUGIN_ROOT,
    POLICY_VERSION,
    PUBLIC,
    load_json,
    plugin_digest,
)


def indexed(items, key):
    result = {}
    for item in items:
        value = item[key]
        assert value not in result, f"duplicate {key}: {value}"
        result[value] = item
    return result


def main():
    internal = load_json(INTERNAL)
    public = load_json(PUBLIC)
    assert internal['schemaVersion'] == 1
    assert public['schemaVersion'] == 1
    assert public['protocol'] == 'mahayana.plugin-marketplace.v1'

    internal_plugins = indexed(internal['plugins'], 'name')
    public_plugins = indexed(public['plugins'], 'id')
    internal_ids = set(internal_plugins)
    disk_ids = {p.name for p in PLUGIN_ROOT.iterdir() if p.is_dir()}
    assert internal_ids == disk_ids, 'internal marketplace registry must exactly match plugin directories'

    for plugin_id, plugin in internal_plugins.items():
        path = PLUGIN_ROOT / plugin_id
        codex = load_json(path / '.codex-plugin/plugin.json')
        mahayana = load_json(path / '.mahayana/plugin.json')
        assert plugin['source'] == {
            'source': 'local',
            'path': f"./plugins/{plugin_id}",
        }
        assert codex['name'] == plugin_id
        assert codex['version'] == plugin['version']
        assert mahayana['schemaVersion'] == 1
        assert (path / '.mcp.json').exists()

    if not APPROVALS.exists():
        # Migration bridge: the first canonical-main auto-publish run creates the
        # approval ledger. Until then preserve the historical strict contract.
        assert internal_ids == set(public_plugins), 'legacy public catalog must match internal registry before ledger initialization'
        for plugin_id, plugin in internal_plugins.items():
            assert public_plugins[plugin_id]['version'] == plugin['version']
        print(f'official marketplace legacy contract valid: {len(internal_ids)} plugins; approval ledger pending initialization')
        return

    approvals_doc = load_json(APPROVALS)
    assert approvals_doc['schemaVersion'] == 1
    assert approvals_doc['protocol'] == APPROVAL_PROTOCOL
    assert approvals_doc['policyVersion'] == POLICY_VERSION
    approvals = indexed(approvals_doc['plugins'], 'id')
    assert set(public_plugins) == set(approvals), 'public catalog must exactly match approved ledger entries'

    for plugin_id, approval in approvals.items():
        public_plugin = public_plugins[plugin_id]
        assert approval['decision'] == 'approved'
        assert approval['policyVersion'] == POLICY_VERSION
        assert public_plugin['version'] == approval['version']
        audit = public_plugin.get('audit')
        assert isinstance(audit, dict), f'{plugin_id} public catalog entry is missing audit proof'
        assert audit['protocol'] == 'fabushi.marketplace.audit.v1'
        assert audit['policyVersion'] == POLICY_VERSION
        assert audit['decision'] == 'approved'
        assert audit['digest'] == approval['digest']

        # A source change under an already-published version invalidates the
        # approval immediately. A version bump may coexist with the previous
        # public release until canonical-main auto-publish advances the ledger.
        current = internal_plugins.get(plugin_id)
        if current and current['version'] == approval['version']:
            digest, _, _, digest_findings = plugin_digest(PLUGIN_ROOT / plugin_id)
            assert not digest_findings, f'{plugin_id} contains forbidden package structure'
            assert digest == approval['digest'], f'{plugin_id}@{approval["version"]} changed after approval; bump version'

    print(
        f'official marketplace approval contract valid: {len(internal_ids)} registered, '
        f'{len(public_plugins)} publicly approved plugins'
    )


if __name__ == '__main__':
    main()
