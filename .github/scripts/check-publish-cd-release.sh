#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys

publish_workflow = Path('.github/workflows/publish-cd-release.yml').read_text(encoding='utf-8')
deploy_workflow = Path('.github/workflows/deploy-production.yml').read_text(encoding='utf-8')

checkout_match = re.search(
    r"- name: Checkout source for version metadata\n(?P<body>.*?)\n\s*- name: Prepare release assets",
    publish_workflow,
    re.DOTALL,
)
if not checkout_match:
    sys.stderr.write('Could not find the version metadata checkout step in publish-cd-release.yml\n')
    raise SystemExit(1)

checkout_body = checkout_match.group('body')
missing = []
for required in ('clean: false', 'path: version-metadata'):
    if required not in checkout_body:
        missing.append(required)

release_asset_requirements = (
    'TESTFLIGHT_UPLOAD_STATUS.txt',
    'IOS_SIGNING_NOT_CONFIGURED.txt',
    'TestFlight upload:',
    'accepted_by_app_store_connect',
    'app_store_connect_upload_failed',
    'app_store_connect_credentials_not_configured',
    'ios_signing_not_configured',
)
for required in release_asset_requirements:
    if required not in publish_workflow:
        missing.append(required)

expected_migration_commands = (
    'run: npx --yes wrangler@latest d1 migrations apply DB --env development --remote',
    'run: npx --yes wrangler@latest d1 migrations apply DB --env production --remote',
)
for required in expected_migration_commands:
    if required not in deploy_workflow:
        missing.append(required)

invalid_migration_commands = (
    'run: npx --yes wrangler@latest d1 migrations apply DB --env development --remote --yes',
    'run: npx --yes wrangler@latest d1 migrations apply DB --env production --remote --yes',
)
for invalid in invalid_migration_commands:
    if invalid in deploy_workflow:
        missing.append(f'invalid command still present: {invalid}')

if missing:
    sys.stderr.write(
        'workflow guardrails are missing required protections: ' + ', '.join(missing) + '\n'
    )
    raise SystemExit(1)

print('publish release and deploy workflow guardrails are in place')
PY