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

migration_steps = re.findall(
    r"run:\s*(npx --yes wrangler@latest d1 migrations apply DB --env (development|production) --remote(?:\s+\S+)*)",
    deploy_workflow,
)

if len(migration_steps) != 2:
    missing.append('development/production D1 migration steps')

for command, environment in migration_steps:
    if command.strip().endswith('--yes'):
        missing.append(f'{environment} D1 migration command should not pass wrangler --yes')

if missing:
    sys.stderr.write(
        'workflow guardrails are missing required protections: ' + ', '.join(missing) + '\n'
    )
    raise SystemExit(1)

print('publish release and deploy workflow guardrails are in place')
PY