#!/usr/bin/env python3
from pathlib import Path

def read_source(path: str, *, optional: bool = False):
    source = Path(path)
    if source.exists():
        return source.read_text(encoding='utf-8')
    if optional:
        return None
    raise SystemExit(f'auth entry gate: required source missing from checkout: {path}')


host = read_source('frontend/apps/web/src/app/host/host-client.tsx')
worker = read_source('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api.rs')
product = read_source('third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs')
feature = read_source('third_party/mahayana/mahayana-rs/mahayana-feature-host/src/implementation.rs')
app_host = read_source('third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs')
main = read_source('desktop/electron/main.cjs')
host_process = read_source('desktop/electron/host-process.cjs')

full_contract_sources = {
    'mahayana_host': ('third_party/mahayana/mahayana-rs/mahayana-host/src/lib.rs', read_source('third_party/mahayana/mahayana-rs/mahayana-host/src/lib.rs', optional=True)),
    'worker_config': ('third_party/mahayana/mahayana-rs/mahayana-platform-worker/wrangler.toml', read_source('third_party/mahayana/mahayana-rs/mahayana-platform-worker/wrangler.toml', optional=True)),
    'account_status_migration': ('third_party/mahayana/mahayana-rs/mahayana-platform-worker/account-migrations/0003_oauth_attempt_failed_status.sql', read_source('third_party/mahayana/mahayana-rs/mahayana-platform-worker/account-migrations/0003_oauth_attempt_failed_status.sql', optional=True)),
    'staging_auth_repair': ('.github/workflows/mahayana-staging-auth-repair.yml', read_source('.github/workflows/mahayana-staging-auth-repair.yml', optional=True)),
    'identity_auth': ('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/identity_auth.rs', read_source('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/identity_auth.rs', optional=True)),
    'registration_schema': ('third_party/mahayana/mahayana-rs/mahayana-platform-worker/account-migrations/0004_email_registration_challenges.sql', read_source('third_party/mahayana/mahayana-rs/mahayana-platform-worker/account-migrations/0004_email_registration_challenges.sql', optional=True)),
    'legacy_bridge': ('fabushi/web/src/handlers/auth-provider-bridge.js', read_source('fabushi/web/src/handlers/auth-provider-bridge.js', optional=True)),
    'legacy_alipay': ('fabushi/web/alipay-login-functions.js', read_source('fabushi/web/alipay-login-functions.js', optional=True)),
    'bridge_deploy': ('.github/scripts/deploy-auth-provider-bridge.sh', read_source('.github/scripts/deploy-auth-provider-bridge.sh', optional=True)),
}
full_contract = all(text is not None for _path, text in full_contract_sources.values())
if full_contract:
    mahayana_host = full_contract_sources['mahayana_host'][1]
    worker_config = full_contract_sources['worker_config'][1]
    account_status_migration = full_contract_sources['account_status_migration'][1]
    staging_auth_repair = full_contract_sources['staging_auth_repair'][1]
    identity_auth = full_contract_sources['identity_auth'][1]
    registration_schema = full_contract_sources['registration_schema'][1]
    legacy_bridge = full_contract_sources['legacy_bridge'][1]
    legacy_alipay = full_contract_sources['legacy_alipay'][1]
    bridge_deploy = full_contract_sources['bridge_deploy'][1]
else:
    missing = [path for path, text in full_contract_sources.values() if text is None]
    print('Auth deployment/provider contract checks deferred to full checkout; sparse checkout omitted: ' + ', '.join(missing))

required = {
    'worker browser start route': (worker, '/api/auth/browser/start'),
    'worker browser portal route': (worker, '/api/auth/browser/portal'),
    'worker browser password route': (worker, '/api/auth/browser/password'),
    'worker one-time attempt poll': (worker, '/api/auth/browser/attempts/:attempt_id'),
    'worker safe return scheme': (worker, 'fabushi://auth/complete?attemptId='),
    'product browser start': (product, 'mahayana.auth.browser.start'),
    'product browser poll': (product, 'mahayana.auth.browser.poll'),
    'product encrypts browser poll verifier': (product, 'save_browser_login_poll_secret'),
    'product strips browser poll verifier': (product, 'object.remove("pollSecret")'),
    'worker requires browser poll verifier': (worker, 'browser_poll_forbidden'),
    'worker browser poll proof body': (worker, 'let poll: BrowserLoginProofRequest = match request.json().await'),
    'worker one-time delivery compare-and-set': (worker, 'if delivery.meta()?.and_then(|meta| meta.changes).unwrap_or(0) == 0'),
    'worker browser cancel route': (worker, '/api/auth/browser/attempts/:attempt_id/cancel'),
    'worker browser reopen route': (worker, '/api/auth/browser/attempts/:attempt_id/reopen'),
    'worker browser reopen verifier': (worker, 'browser_reopen_forbidden'),
    'product browser reopen': (product, 'mahayana.auth.browser.reopen'),
    'feature browser reopen': (feature, 'browser_login_reopen'),
    'app host browser reopen': (app_host, 'feature.auth.browserReopen'),
    'renderer secure reopen': (host, 'transport.browserLoginReopen(attempt.attemptId)'),
    'worker browser cancel verifier': (worker, 'browser_cancel_forbidden'),
    'product browser cancel': (product, 'mahayana.auth.browser.cancel'),
    'feature browser cancel': (feature, 'browser_login_cancel'),
    'app host browser cancel': (app_host, 'feature.auth.browserCancel'),
    'renderer server-side cancel': (host, 'transport.browserLoginCancel(attempt.attemptId)'),
    'renderer failed terminal': (host, 'result.status === "failed"'),
    'feature browser start': (feature, 'browser_login_start'),
    'feature browser poll': (feature, 'browser_login_poll'),
    'app host browser start': (app_host, 'feature.auth.browserStart'),
    'app host browser poll': (app_host, 'feature.auth.browserPoll'),
    'electron auth deep link': (main, "route: 'auth'"),
    'renderer browser start': (host, 'transport.browserLoginStart()'),
    'renderer browser poll': (host, 'transport.browserLoginPoll(attempt.attemptId)'),
    'renderer single browser CTA': (host, 'data-testid="browser-login-start"'),
    'feature browser credential-boundary regression': (feature, 'deterministic_browser_login_keeps_credentials_out_of_the_presentation_boundary'),
    'desktop defaults to Rust staging Product API': (host_process, "DEFAULT_DESKTOP_PRODUCT_API_BASE_URL = 'https://mahayana-platform.bhrumom.workers.dev'"),
    'desktop forwards Product API override to Host': (host_process, 'MAHAYANA_API_BASE_URL:'),
    'browser registration code route': (worker, '/api/auth/browser/register/code'),
    'browser registration submit route': (worker, '/api/auth/browser/register'),
    'browser login/register UI tabs': (worker, 'aria-label=\"账号模式\"'),
    'worker browser poll uses POST': (worker, '.post_async(\"/api/auth/browser/attempts/:attempt_id\", browser_login_poll)'),
}
if full_contract:
    required.update({
        'provider PKCE challenge': (identity_auth, 'code_challenge_method'),
        'Mahayana Host honors Product API override with explicit state paths': (mahayana_host, 'env::var("MAHAYANA_API_BASE_URL")'),
        'staging browser origin': (worker_config, 'AUTH_PUBLIC_BASE_URL = "https://mahayana-platform.bhrumom.workers.dev"'),
        'oauth failed terminal schema': (account_status_migration, "'cancelled', 'failed'"),
        'staging auth repair applies account auth migrations': (staging_auth_repair, 'd1 migrations apply ACCOUNT_DB --remote'),
        'staging auth repair verifies browser broker': (staging_auth_repair, 'Verify browser login, registration, and Alipay broker lifecycle'),
        'staging auth repair posts browser poll proof': (staging_auth_repair, "jq -e '.status == \"pending\"'"),
        'provider registry includes Apple': (identity_auth, '"apple"'),
        'provider registry includes Alipay': (identity_auth, '"alipay"'),
        'provider registry includes Cloudflare': (identity_auth, '"cloudflare"'),
        'Apple uses form post': (identity_auth, 'response_mode'),
        'Apple requests id token': (identity_auth, 'code id_token'),
        'Apple validates JWKS': (identity_auth, 'DecodingKey::from_jwk'),
        'Apple validates issuer': (identity_auth, 'validation.set_issuer'),
        'Apple validates audience': (identity_auth, 'validation.set_audience'),
        'Apple validates nonce': (identity_auth, 'Apple identity nonce mismatch'),
        'GitHub verified email lookup': (identity_auth, 'https://api.github.com/user/emails'),
        'Cloudflare identity-only scope': (identity_auth, 'user-details.read'),
        'registration stores only code hash': (registration_schema, 'code_hash TEXT NOT NULL'),
        'registration failed-attempt limiter': (registration_schema, 'failed_attempts INTEGER NOT NULL'),
        'Alipay bridge requires server proof': (legacy_bridge, 'X-Fabushi-Auth-Bridge'),
        'Alipay bridge rejects mock identity': (legacy_bridge, 'identity.isMock'),
        'legacy Alipay callback returns browser state to Rust': (legacy_alipay, 'AUTH_PROVIDER_BRIDGE_RETURN_BASE'),
        'bridge deploy only lists secret names': (bridge_deploy, 'secret list --env'),
        'bridge deploy masks generated proof': (bridge_deploy, '::add-mask::'),
    })

for label, (text, marker) in required.items():
    if marker not in text:
        raise SystemExit(f'auth entry gate: missing {label}: {marker}')


if '.find_map(|(key, value)| (key == "pollSecret")' in worker or '&[("pollSecret", poll_secret.as_str())]' in product:
    raise SystemExit('auth entry gate: browser poll verifier must not be sent in a URL query string')

for forbidden in [
    'data-testid={`oauth-${provider.id}`}',
    'data-testid="password-login-toggle"',
    'data-testid="login-username"',
    'data-testid="login-password"',
    'transport.passwordLogin(',
    'transport.oauthStart(',
]:
    if forbidden in host:
        raise SystemExit(f'auth entry gate: desktop login regressed to in-app auth: {forbidden}')

# Deep links are a wake-up hint only: never allow credential names into the
# custom scheme builder/parser.
auth_deep_link_region = main[main.find("hostName === 'auth'"):main.find("hostName === 'settings'")]
for secret_name in ['accessToken', 'refreshToken', 'password', 'codeVerifier']:
    if secret_name in auth_deep_link_region:
        raise SystemExit(f'auth entry gate: secret-like field leaked into auth deep link: {secret_name}')

print('Browser auth entry gate passed: provider selection and credentials stay in the browser portal.')

# Cross-runtime parity: every checked-out Rust bridge that exposes the legacy
# OAuth command must expose the full browser-first lifecycle too.
rust_bridges = []
for path in Path('.').rglob('*.rs'):
    if any(part in {'.git', 'target', 'node_modules'} for part in path.parts):
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError):
        continue
    if 'feature_host_oauth_start' in text:
        rust_bridges.append((path, text))
for path, text in rust_bridges:
    for command in [
        'feature_host_browser_login_start',
        'feature_host_browser_login_poll',
        'feature_host_browser_login_cancel',
        'feature_host_browser_login_reopen',
    ]:
        if command not in text:
            raise SystemExit(f'auth entry gate: Tauri/native browser auth bridge missing {command}: {path}')
if rust_bridges:
    print(f'Tauri/native browser auth bridge coverage: {len(rust_bridges)} source(s).')

if full_contract:
    for forbidden in ['dangerous_insecure_decode', 'decode_payload', 'identityToken.split']:
        if forbidden in identity_auth:
            raise SystemExit(f'auth entry gate: insecure Apple token handling returned: {forbidden}')
    if 'code TEXT NOT NULL' in registration_schema:
        raise SystemExit('auth entry gate: registration verification code must never be persisted in plaintext')
