#!/usr/bin/env python3
from pathlib import Path

host = Path('frontend/apps/web/src/app/host/host-client.tsx').read_text(encoding='utf-8')
worker = Path('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api.rs').read_text(encoding='utf-8')
product = Path('third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs').read_text(encoding='utf-8')
feature = Path('third_party/mahayana/mahayana-rs/mahayana-feature-host/src/implementation.rs').read_text(encoding='utf-8')
app_host = Path('third_party/mahayana/mahayana-rs/mahayana-app-host/src/lib.rs').read_text(encoding='utf-8')
main = Path('desktop/electron/main.cjs').read_text(encoding='utf-8')
host_process = Path('desktop/electron/host-process.cjs').read_text(encoding='utf-8')
mahayana_host = Path('third_party/mahayana/mahayana-rs/mahayana-host/src/lib.rs').read_text(encoding='utf-8')
worker_config = Path('third_party/mahayana/mahayana-rs/mahayana-platform-worker/wrangler.toml').read_text(encoding='utf-8')
account_status_migration = Path('third_party/mahayana/mahayana-rs/mahayana-platform-worker/account-migrations/0003_oauth_attempt_failed_status.sql').read_text(encoding='utf-8')
staging_auth_repair = Path('.github/workflows/mahayana-staging-auth-repair.yml').read_text(encoding='utf-8')

required = {
    'worker browser start route': (worker, '/api/auth/browser/start'),
    'worker browser portal route': (worker, '/api/auth/browser/portal'),
    'worker browser password route': (worker, '/api/auth/browser/password'),
    'worker one-time attempt poll': (worker, '/api/auth/browser/attempts/:attempt_id'),
    'worker PKCE challenge': (worker, 'code_challenge_method'),
    'worker safe return scheme': (worker, 'fabushi://auth/complete?attemptId='),
    'product browser start': (product, 'mahayana.auth.browser.start'),
    'product browser poll': (product, 'mahayana.auth.browser.poll'),
    'product encrypts browser poll verifier': (product, 'save_browser_login_poll_secret'),
    'product strips browser poll verifier': (product, 'object.remove("pollSecret")'),
    'worker requires browser poll verifier': (worker, 'browser_poll_forbidden'),
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
    'Mahayana Host honors Product API override with explicit state paths': (mahayana_host, 'env::var("MAHAYANA_API_BASE_URL")'),
    'staging browser origin': (worker_config, 'AUTH_PUBLIC_BASE_URL = "https://mahayana-platform.bhrumom.workers.dev"'),
    'oauth failed terminal schema': (account_status_migration, "'cancelled', 'failed'"),
    'staging auth repair applies account auth migrations': (staging_auth_repair, 'd1 migrations apply ACCOUNT_DB --remote'),
    'staging auth repair verifies browser broker': (staging_auth_repair, 'Verify browser login broker lifecycle'),
}
for label, (text, marker) in required.items():
    if marker not in text:
        raise SystemExit(f'auth entry gate: missing {label}: {marker}')

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
