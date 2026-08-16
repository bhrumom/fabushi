#!/usr/bin/env python3
from pathlib import Path

host = Path('frontend/apps/web/src/app/host/host-client.tsx').read_text(encoding='utf-8')
styles = Path('frontend/apps/web/src/app/host/host.module.css').read_text(encoding='utf-8')

required_host = [
    'data-testid="browser-login-start"',
    'data-testid="browser-login-reopen"',
    'data-testid="browser-login-cancel"',
    'data-testid="account-menu"',
    'onClick={() => setAccountOpen(true)}',
    'onboardingStep === 0',
    'onboardingStep === 1',
    'onboardingStep === 2',
    'className={styles.onboardingMarkStage}',
    'className={styles.accountAvatarStage}',
    'onClick={() => openMiniApp(app.id)}',
]
for marker in required_host:
    if marker not in host:
        raise SystemExit(f'product UI gate: missing required user-facing path: {marker}')

# The historical stylesheet once permanently hid the marketplace Open button.
# The final cascade must explicitly restore it.
open_button_rule = '.marketRow button:nth-of-type(2) { display: inline-flex; }'
if styles.rfind(open_button_rule) < styles.rfind('.marketRow button:nth-of-type(2) { display: none; }'):
    raise SystemExit('product UI gate: installed plugins are not visually openable')

required_styles = [
    '.loginExperience',
    '.onboardingHeader',
    '.accountSessionGrid',
    '.marketTabs',
    '.networkTabs',
    '.automationDialog',
    '.trayPopover',
    '.computerPanel',
    '.cloudRunGrid',
]
for marker in required_styles:
    if marker not in styles:
        raise SystemExit(f'product UI gate: missing unified surface style: {marker}')

print('Product UI contract gate passed: login, identity, onboarding, extensions, network, automation and runtime surfaces remain reachable.')
