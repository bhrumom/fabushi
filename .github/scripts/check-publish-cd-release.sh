#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import sys

deploy_workflow = Path('.github/workflows/deploy-production.yml').read_text(encoding='utf-8')
auth_utils = Path('fabushi/web/auth-utils.js').read_text(encoding='utf-8')
auth_handler = Path('fabushi/web/src/handlers/auth.js').read_text(encoding='utf-8')
password_login = Path('fabushi/web/src/handlers/password-login.js').read_text(encoding='utf-8')
profile_handler = Path('fabushi/web/src/handlers/profile.js').read_text(encoding='utf-8')
profile_test = Path('fabushi/web/tests/profile.test.js').read_text(encoding='utf-8')
auth_user_id_test = Path('fabushi/web/tests/auth-user-id.test.js').read_text(encoding='utf-8')
identity_migration = Path('fabushi/web/migrations/20260508_users_id_identity.sql').read_text(encoding='utf-8')

missing = []

for required in (
    'mkdir -p ../release-artifact/github-scripts',
    'cp -R ../.github/scripts/. ../release-artifact/github-scripts',
    'run: bash ../../github-scripts/run-wrangler-d1-migrations.sh DB development',
    'run: bash ../../github-scripts/run-wrangler-d1-migrations.sh DB production',
):
    if required not in deploy_workflow:
        missing.append(f'deploy workflow missing: {required}')

for required in (
    'env?.DB?.prepare',
    'SELECT id FROM users WHERE username = ?',
    'payload.userId',
):
    if required not in auth_utils:
        missing.append(f'auth-utils missing: {required}')

for required in (
    'getUserById',
    'WHERE id = ?',
    'existingUser.id !== currentUser.id',
    'INSERT OR REPLACE INTO email_username_mapping (email, username, user_id)',
):
    if required not in profile_handler:
        missing.append(f'profile.js missing: {required}')

for required in (
    'generateToken({ id: user.id, username: user.username }, env)',
    'userId: user.id',
):
    if required not in password_login:
        missing.append(f'password-login.js missing: {required}')

for required in (
    'generateToken({ id: user.id, username: user.username }, env)',
    'resolveAuthenticatedUser',
):
    if required not in auth_handler:
        missing.append(f'auth.js missing: {required}')

for required in (
    'handleUpdateProfile uses token userId before mismatched username fallback',
    'handleUpdateProfile treats legacy username payload as display name and keeps identity username stable',
):
    if required not in profile_test:
        missing.append(f'profile.test.js missing: {required}')

for required in (
    'new token keeps userId and old token remains compatible',
    'auth handler prefers token userId over mismatched username',
):
    if required not in auth_user_id_test:
        missing.append(f'auth-user-id.test.js missing: {required}')

for required in (
    'CREATE TABLE users__id_migration',
    'SELECT\n  rowid,',
    'CREATE TABLE email_username_mapping__user_id_migration',
    'CREATE TABLE alipay_bindings__user_id_migration',
    'idx_email_username_mapping_user_id',
    'idx_alipay_bindings_user_id',
):
    if required not in identity_migration:
        missing.append(f'identity migration missing: {required}')

if missing:
    sys.stderr.write('workflow guardrails are missing required protections: ' + ', '.join(missing) + '\n')
    raise SystemExit(1)

print('publish release and auth userId guardrails are in place')
PY
