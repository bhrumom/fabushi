#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import sys

deploy_workflow = Path('.github/workflows/deploy-production.yml').read_text(encoding='utf-8')
publish_release_workflow = Path('.github/workflows/publish-cd-release.yml').read_text(encoding='utf-8')
auth_utils = Path('fabushi/web/auth-utils.js').read_text(encoding='utf-8')
auth_handler = Path('fabushi/web/src/handlers/auth.js').read_text(encoding='utf-8')
password_login = Path('fabushi/web/src/handlers/password-login.js').read_text(encoding='utf-8')
profile_handler = Path('fabushi/web/src/handlers/profile.js').read_text(encoding='utf-8')
thirdparty_handler = Path('fabushi/web/src/handlers/thirdparty.js').read_text(encoding='utf-8')
database_service = Path('fabushi/web/src/services/database.js').read_text(encoding='utf-8')
profile_test = Path('fabushi/web/tests/profile.test.js').read_text(encoding='utf-8')
auth_user_id_test = Path('fabushi/web/tests/auth-user-id.test.js').read_text(encoding='utf-8')
database_user_id_test = Path('fabushi/web/tests/database-user-id.test.js').read_text(encoding='utf-8')
identity_migration = Path('fabushi/web/migrations/20260508_users_id_identity.sql').read_text(encoding='utf-8')
payment_migration_path = Path('fabushi/web/migrations/20260508_users_payment_columns.sql')
payment_migration = payment_migration_path.read_text(encoding='utf-8')
auth_route = Path('fabushi/web/src/routes/auth-routes.js').read_text(encoding='utf-8')
membership_route = Path('fabushi/web/src/routes/membership-routes.js').read_text(encoding='utf-8')
meditation_route = Path('fabushi/web/src/routes/meditation-routes.js').read_text(encoding='utf-8')
account_contract = Path('fabushi/web/src/contracts/account-user.js').read_text(encoding='utf-8')
account_repository = Path('fabushi/web/src/repositories/account-user-repository.js').read_text(encoding='utf-8')
account_command_repository = Path('fabushi/web/src/repositories/account-user-command-repository.js').read_text(encoding='utf-8')
update_profile_use_case = Path('fabushi/web/src/use-cases/update-profile.js').read_text(encoding='utf-8')
register_account_use_case = Path('fabushi/web/src/use-cases/account-registration.js').read_text(encoding='utf-8')
bind_email_use_case = Path('fabushi/web/src/use-cases/bind-email.js').read_text(encoding='utf-8')
delete_account_use_case = Path('fabushi/web/src/use-cases/delete-account.js').read_text(encoding='utf-8')

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
    'Check CD artifacts for source metadata',
    'steps.cd-artifacts.outputs.has_artifacts == \'true\'',
    'Checkout source for change detection',
    'sparse-checkout-cone-mode: false',
    'sparse-checkout: |\n            /.github/**',
    'mobile_reasons=()',
    'non_mobile_reasons=()',
    'frontend/*)',
    'official site input does not require mobile install packages',
    'Worker/API input does not require mobile install packages',
    'CI/CD guardrail input does not require mobile install packages',
    'PR label explicitly requests fresh install packages',
    'force[- ]?mobile[- ]?release|mobile[- ]?release|build[- ]?mobile[- ]?package|build[- ]?app[- ]?package',
    'Android package build when Android or shared Flutter app inputs changed, or an explicit PR label requests it',
    'iOS package build when iOS or shared Flutter app inputs changed, or an explicit PR label requests it',
    'This workflow publishes install packages after the main production CD workflow succeeds and the change detector finds mobile app package inputs.',
    'Capture app screenshots',
    'if: ${{ false }}',
    'Official site screenshots are now maintained manually in frontend/apps/web/public/product.',
):
    if required not in publish_release_workflow:
        missing.append(f'publish release workflow missing: {required}')

for forbidden in (
    '      - name: Checkout source for change detection\n        uses: actions/checkout@v5\n        with:\n          ref: ${{ steps.source.outputs.source_sha }}\n          fetch-depth: 0\n\n      - name: Detect changed mobile package targets',
    '- Android package build only when Android-specific or shared mobile code changes',
    '- iOS package build only when iOS-specific or shared mobile code changes',
    '- This workflow publishes install packages only after the main production CD workflow succeeds and mobile package inputs changed.',
    'runtime/API/account-impacting input changed',
    'PR metadata indicates account/auth/user/payment behavior needs fresh install packages',
    '(account|auth|login|logout|profile|user[ -]?id|membership|subscription|payment|billing|identity|credential|token|session|force[- ]?mobile[- ]?release|mobile[- ]?release|账号|账户|登录|用户|会员|支付)',
    'release or deployment pipeline changed',
    'Android package build when Android, shared app, release pipeline, or account/API runtime inputs changed',
    'iOS package build when iOS, shared app, release pipeline, or account/API runtime inputs changed',
    '      - name: Download product screenshots\n        if: needs.capture-screenshots.result == \'success\'\n        uses: actions/download-artifact@v5\n        with:',
    '          name: release-product-screenshots\n          path: release-screenshots\n          if-no-files-found: warn',
):
    if forbidden in publish_release_workflow:
        missing.append(f'publish release workflow should not contain: {forbidden}')

for required in (
    'env?.DB?.prepare',
    'SELECT id FROM users WHERE username = ?',
    'payload.userId',
):
    if required not in auth_utils:
        missing.append(f'auth-utils missing: {required}')

for required in (
    'AccountUserRepository',
    'updateProfileFromRequest',
    'serializeAccountUser',
):
    if required not in profile_handler:
        missing.append(f'profile.js missing: {required}')

for required in (
    'loginWithPasswordCommand',
    'AccountUserRepository',
    'jsonResponse(payload)',
):
    if required not in password_login:
        missing.append(f'password-login.js missing: {required}')

for required in (
    'generateToken({ id: user.id, username: user.username }, env)',
    'resolveAuthenticatedUser',
    'registerAccountCommand',
    'getAuthenticatedUserInfo',
    'deleteAccountCommand',
):
    if required not in auth_handler:
        missing.append(f'auth.js missing: {required}')

for required in (
    'bindEmailFromRequest',
    'AccountUserRepository',
    "jsonResponse({ error: apiError.message }, apiError.status)",
):
    if required not in thirdparty_handler:
        missing.append(f'thirdparty.js missing: {required}')

for required in (
    'export const USER_ID_CUSTOM_EPOCH_MS = Date.UTC(2025, 0, 1);',
    'export const USER_ID_MAX_WORKER_ID',
    'export const USER_ID_MAX_SEQUENCE',
    'export function generateSnowflakeUserId',
    'const candidate = generateSnowflakeUserId();',
    "无法生成可用的雪花式用户 ID",
):
    if required not in database_service:
        missing.append(f'database.js missing: {required}')

for forbidden in (
    'generateSixDigitId',
    'hasObviousPattern',
    '6 位用户 ID',
):
    if forbidden in database_service:
        missing.append(f'database.js should not contain: {forbidden}')

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
    'snowflake user ids stay monotonic and within safe integer range',
    'snowflake user ids roll forward after one-millisecond sequence is exhausted',
    'snowflake worker id normalization keeps ids deterministic',
):
    if required not in database_user_id_test:
        missing.append(f'database-user-id.test.js missing: {required}')

for required in (
    'PRAGMA defer_foreign_keys = ON;',
    'ALTER TABLE email_username_mapping RENAME TO email_username_mapping__legacy;',
    'ALTER TABLE alipay_bindings RENAME TO alipay_bindings__legacy;',
    'ALTER TABLE users RENAME TO users__legacy;',
    'DROP TABLE users__legacy;',
    'CREATE TABLE email_username_mapping (',
    'CREATE TABLE alipay_bindings (',
    'idx_email_username_mapping_user_id',
    'idx_alipay_bindings_user_id',
):
    if required not in identity_migration:
        missing.append(f'identity migration missing: {required}')

for forbidden in (
    'PRAGMA foreign_keys = OFF;',
    'DROP TABLE users;',
    'ALTER TABLE users__id_migration RENAME TO users;',
    'binding.id,',
):
    if forbidden in identity_migration:
        missing.append(f'identity migration should not contain: {forbidden}')

for required in (
    'ALTER TABLE users ADD COLUMN stripe_customer_id TEXT',
    'ALTER TABLE users ADD COLUMN subscription_id TEXT',
):
    if required not in payment_migration:
        missing.append(f'payment migration missing: {required}')

if Path('fabushi/web/migrations/20260508_users_customer_payment_columns.sql').exists():
    missing.append('duplicate payment migration filename should not be reintroduced')

for required in (
    'stripe_customer_id',
    'subscription_id',
):
    if required not in identity_migration:
        missing.append(f'identity migration must preserve payment column: {required}')

for required in (
    "'/api/auth/update-profile'",
    'handleGetUserInfo',
    'handleBindEmail',
    'handleDeleteAccount',
):
    if required not in auth_route:
        missing.append(f'auth-routes.js missing: {required}')

for required in (
    "'/api/stripe/membership-status'",
    "'/api/admin/purchase-history'",
    'handleUseRedeemCode',
):
    if required not in membership_route:
        missing.append(f'membership-routes.js missing: {required}')

for required in (
    "'/api/meditation/groups'",
    'handleCreateMeditationGroup',
    'handleSyncRecord',
):
    if required not in meditation_route:
        missing.append(f'meditation-routes.js missing: {required}')

for required in (
    'serializeAccountUser',
    'buildPasswordLoginPayload',
    'buildProfileUpdatedPayload',
):
    if required not in account_contract:
        missing.append(f'account-user contract missing: {required}')

for required in (
    'resolveTokenUser',
    'UPDATE users SET',
    'INSERT OR REPLACE INTO email_username_mapping (email, username, user_id)',
):
    if required not in account_repository:
        missing.append(f'account-user repository missing: {required}')

for required in (
    'createRegisteredUser',
    'withTransaction',
    'deleteAccountArtifacts',
):
    if required not in account_command_repository:
        missing.append(f'account-user command repository missing: {required}')

for required in (
    'normalizeProfileUpdateBody',
    'existingUser.id !== currentUser.id',
    'buildProfileUpdatedPayload',
):
    if required not in update_profile_use_case:
        missing.append(f'update-profile use case missing: {required}')

for required in (
    'env.USERS_KV.get(`verify:${normalizedEmail}`)',
    'repository.createRegisteredUser',
    "return { message: '注册成功' }",
):
    if required not in register_account_use_case:
        missing.append(f'account-registration use case missing: {required}')

for required in (
    'authenticateRequest',
    'normalizeEmail',
    "message: '邮箱绑定成功'",
):
    if required not in bind_email_use_case:
        missing.append(f'bind-email use case missing: {required}')

for required in (
    'repository.withTransaction',
    'repository.deleteAccountArtifacts',
    "message: '账户已注销'",
):
    if required not in delete_account_use_case:
        missing.append(f'delete-account use case missing: {required}')

if missing:
    sys.stderr.write('workflow guardrails are missing required protections: ' + ', '.join(missing) + '\n')
    raise SystemExit(1)

print('publish release and auth userId guardrails are in place')
PY
