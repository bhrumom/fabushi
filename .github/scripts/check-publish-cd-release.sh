#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys

publish_workflow = Path('.github/workflows/publish-cd-release.yml').read_text(encoding='utf-8')
deploy_workflow = Path('.github/workflows/deploy-production.yml').read_text(encoding='utf-8')
co_practice_migration = Path('fabushi/web/migrations/20260506_co_practice_groups.sql')
d1_retry_helper = Path('.github/scripts/run-wrangler-d1-migrations.sh')

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

expected_deploy_requirements = (
    'cp -R ../.github/scripts ../release-artifact/.github/scripts',
    'run: bash ../../.github/scripts/run-wrangler-d1-migrations.sh DB development',
    'run: bash ../../.github/scripts/run-wrangler-d1-migrations.sh DB production',
)
for required in expected_deploy_requirements:
    if required not in deploy_workflow:
        missing.append(required)

invalid_migration_commands = (
    'run: npx --yes wrangler@latest d1 migrations apply DB --env development --remote',
    'run: npx --yes wrangler@latest d1 migrations apply DB --env production --remote',
    'run: npx --yes wrangler@latest d1 migrations apply DB --env development --remote --yes',
    'run: npx --yes wrangler@latest d1 migrations apply DB --env production --remote --yes',
)
for invalid in invalid_migration_commands:
    if invalid in deploy_workflow:
        missing.append(f'invalid command still present: {invalid}')

invalid_deploy_packaging = (
    'cp -R .github/scripts ../release-artifact/.github/scripts',
)
for invalid in invalid_deploy_packaging:
    if invalid in deploy_workflow:
        missing.append(f'invalid helper packaging still present: {invalid}')

if not d1_retry_helper.exists():
    missing.append('.github/scripts/run-wrangler-d1-migrations.sh')
else:
    helper_text = d1_retry_helper.read_text(encoding='utf-8')
    for required in (
        'Upstream service unavailable \\[code: 7009\\]',
        'WRANGLER_D1_MAX_ATTEMPTS',
        'npx --yes wrangler@latest d1 migrations apply',
    ):
        if required not in helper_text:
            missing.append(f'd1 retry helper missing: {required}')

if not co_practice_migration.exists():
    missing.append('fabushi/web/migrations/20260506_co_practice_groups.sql')
else:
    migration_text = co_practice_migration.read_text(encoding='utf-8')
    for required in (
        'CREATE TABLE IF NOT EXISTS meditation_groups',
        'CREATE TABLE IF NOT EXISTS meditation_group_members',
        'CREATE INDEX IF NOT EXISTS idx_meditation_group_members_status ON meditation_group_members(status);',
    ):
        if required not in migration_text:
            missing.append(f'co-practice migration missing: {required}')

    for forbidden in (
        'ALTER TABLE meditation_records ADD COLUMN local_time TEXT;',
        'ALTER TABLE meditation_records ADD COLUMN timezone_offset_minutes INTEGER;',
        'ALTER TABLE meditation_records ADD COLUMN start_time TEXT;',
        'ALTER TABLE meditation_records ADD COLUMN end_time TEXT;',
    ):
        if forbidden in migration_text:
            missing.append(f'co-practice migration should not re-add existing meditation_records columns: {forbidden}')

if missing:
    sys.stderr.write(
        'workflow guardrails are missing required protections: ' + ', '.join(missing) + '\n'
    )
    raise SystemExit(1)

print('publish release and deploy workflow guardrails are in place')
PY
