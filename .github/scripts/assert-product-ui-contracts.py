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
    'onDelete={deleteAgentWorkflow}',
    'onDeleteBot={confirmBotDelete}',
    'confirmRemoveAgentFromSharedRoom',
    'confirmLeaveSharedRoom',
    'data-testid="confirm-dialog"',
    'const hasManagedModal = Boolean(',
    "document.addEventListener('keydown', handleKeyDown, true)",
    "if (event.key === 'Tab')",
    "if (event.key !== 'Escape') return",
]
for marker in required_host:
    if marker not in host:
        raise SystemExit(f'product UI gate: missing required user-facing path: {marker}')


host_ui_files = [
    Path('frontend/apps/web/src/app/host/host-client.tsx'),
    Path('frontend/apps/web/src/app/host/agent-workflow-panel.tsx'),
    Path('frontend/apps/web/src/app/host/extension-studio.tsx'),
]
for host_ui_file in host_ui_files:
    if not host_ui_file.is_file():
        raise SystemExit(f'product UI gate: required host UI source is missing: {host_ui_file}')
for host_ui_file in host_ui_files:
    if 'window.confirm(' in host_ui_file.read_text(encoding='utf-8'):
        raise SystemExit(
            f'product UI gate: system confirmation dialogs must not replace Fabushi confirmation surfaces: {host_ui_file}'
        )

# The historical stylesheet once permanently hid the marketplace Open button.
# The final cascade must explicitly restore it.
open_button_rule = '.marketRow button:nth-of-type(2) { display: inline-flex; }'
runtime_status_rule = ".runtimeStatus {\n  display: inline-flex;"
composer_select_rule = ".composerToolbar select {\n  display: block;"
notification_rule = ".titleActions > button:first-child {\n  display: inline-grid;"
automation_rule = ".sidebarFooter > button:first-child {\n  display: flex;"
activity_header_rule = ".activityHeader {\n  display: flex;"
agent_run_rule = ".agentRunCard {\n  display: block;"
if runtime_status_rule not in styles:
    raise SystemExit('product UI gate: runtime Host status is still hidden')
if composer_select_rule not in styles:
    raise SystemExit('product UI gate: composer mode/model selectors are still hidden')
if notification_rule not in styles:
    raise SystemExit('product UI gate: notification/error tray entry is still hidden')
if automation_rule not in styles:
    raise SystemExit('product UI gate: automation entry is still hidden')
if activity_header_rule not in styles or agent_run_rule not in styles:
    raise SystemExit('product UI gate: agent activity observability is still hidden')
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
    '.confirmDialog',
    '.runtimeStatus',
    '.composerToolbar select',
    '.activityHeader',
    '.agentRunCard',
    '.activityPanel',
]
for marker in required_styles:
    if marker not in styles:
        raise SystemExit(f'product UI gate: missing unified surface style: {marker}')

print('Product UI contract gate passed: login, identity, onboarding, extensions, network, automation and runtime surfaces remain reachable.')
