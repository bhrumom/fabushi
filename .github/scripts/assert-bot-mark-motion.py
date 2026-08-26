#!/usr/bin/env python3
from pathlib import Path

component = Path('frontend/apps/web/src/app/host/bot-mark.tsx').read_text(encoding='utf-8')
engine = Path('frontend/apps/web/src/app/host/fabushi-bot-mark-engine.tsx').read_text(encoding='utf-8')
styles = Path('frontend/apps/web/src/app/host/host.module.css').read_text(encoding='utf-8')
host = Path('frontend/apps/web/src/app/host/host-client.tsx').read_text(encoding='utf-8')
identity_aliases = Path('desktop/src/agent-identity-aliases.ts').read_text(encoding='utf-8')
durable_state = Path('desktop/src/durable-agent-state.ts').read_text(encoding='utf-8')
desktop_main = Path('desktop/src/main.tsx').read_text(encoding='utf-8')

required_component = [
    'FabushiBotMarkEngine',
    'data-engine="fabushi-motion-v2"',
    'data-renderer="grok-mark"',
    'data-motion-tier={botMarkMotionTier(state, emphasis, followPointer)}',
    'AMBIENT_MOTION_STATES',
    '"blob", "pebble", "squircle", "tablet", "wedge", "hex", "cloud", "teardrop"',
    'canonicalBotIdentity',
    'registerBotIdentityAliases',
    'useSyncExternalStore(subscribeBotIdentity, botIdentitySnapshot, botIdentitySnapshot)',
    'data-canonical-bot-id={identityId}',
    'botId={identityId}',
]
for marker in required_component:
    if marker not in component:
        raise SystemExit(f'BotMark motion gate: missing semantic/Grok renderer integration: {marker}')

# Identity and activity are separate concerns: list/header/profile/workbench marks
# must use a canonical Bot seed, while state still follows the active Agent run.
for prefix_projection in [
    '/^workbench:(.+)$/u',
    '/^peer:(?:bot|agent):(.+)$/u',
]:
    if prefix_projection not in component:
        raise SystemExit(f'BotMark motion gate: missing canonical surface projection: {prefix_projection}')

required_aliases = [
    "detail.type === 'bot.listed'",
    "detail.type === 'bot.changed'",
    "event.type === 'syncBatch'",
    "event.type === 'botChanged'",
    "event.type === 'botInvocationRequested'",
    "{ alias: `workbench:${botId}`, canonical }",
    "{ alias: `peer:conversation:${conversationId}`, canonical }",
    'registerBotIdentityAliases(aliases)',
]
for marker in required_aliases:
    if marker not in identity_aliases:
        raise SystemExit(f'BotMark motion gate: missing authoritative Bot identity alias projection: {marker}')

required_durability = [
    "AGENT_WORKBENCH_STORAGE_KEY = 'fabushi.desktop.mahayana-agent-workbench.v1'",
    "CONVERSATION_JOURNAL_STORAGE_KEY = 'fabushi.desktop.mahayana-conversation-journal.v1'",
    "SELFHOSTED_INVOCATION_CLAIMS_KEY = 'fabushi.desktop.selfhosted-mahayana-invocations.v1'",
    "invokeNativeDesktop<unknown>('readClientPersistence'",
    "invokeNativeDesktop<boolean>('writeClientPersistence'",
    "invokeNativeDesktop<boolean>('removeClientPersistence'",
    'MAHAYANA_ACCOUNT_SESSION_RESET_EVENT',
]
for marker in required_durability:
    if marker not in durable_state:
        raise SystemExit(f'BotMark motion gate: missing native restart/account-boundary durability contract: {marker}')

for bootstrap_marker in [
    'await restoreDurableAgentState()',
    'installBotIdentityAliases()',
    'installDurableAgentState()',
]:
    if bootstrap_marker not in desktop_main:
        raise SystemExit(f'BotMark motion gate: desktop bootstrap skipped GBF-805 identity/durability stage: {bootstrap_marker}')

required_engine = [
    'const VIEWBOX = "-15 -15 259 259"',
    'const CENTER = 114.2705',
    'normalizeArtifactPath',
    'roundedPolygon',
    'const MOTION:',
    'requestAnimationFrame(tick)',
    'prefers-reduced-motion: reduce',
    'scale(1 ${motion.eye})',
    '<ellipse cx={CENTER - 29}',
    '<ellipse cx={CENTER + 29}',
]
for marker in required_engine:
    if marker not in engine:
        raise SystemExit(f'BotMark motion gate: missing Grok mark behavior: {marker}')

for semantic_state in ['tool-running', 'speaking', 'result', 'error']:
    if f'"{semantic_state}"' not in component or f'"{semantic_state}"' not in engine:
        raise SystemExit(f'BotMark motion gate: missing Agent lifecycle state: {semantic_state}')

for forbidden in ['setInterval(() =>', 'surfaceGradientRef', 'radarSweepRef', 'botMarkParticles']:
    if forbidden in component or forbidden in engine:
        raise SystemExit(f'BotMark motion gate: non-Grok visual effect returned: {forbidden}')

required_styles = [
    '.botMark > svg',
    'filter: none;',
    '.onboardingMarkStage > span:not(.onboardingBotMark)',
    '@media (prefers-reduced-motion: reduce)',
    'animation: none !important;',
]
for marker in required_styles:
    if marker not in styles:
        raise SystemExit(f'BotMark motion gate: missing Grok-compatible CSS contract: {marker}')

# Pointer-follow is intentionally reserved for large hero/profile marks. Keeping
# it out of agent-list rows avoids N pointer listeners for a long sidebar.
if 'className={styles.sidebarBotMark}' in host:
    sidebar_region = host[host.find('className={styles.sidebarBotMark}') - 500:host.find('className={styles.sidebarBotMark}') + 500]
    if 'followPointer' in sidebar_region:
        raise SystemExit('BotMark motion gate: sidebar list marks must not attach pointer-follow listeners')

print('BotMark motion gate passed: stable canonical Bot identity, native restart durability, Grok geometry/eyes, semantic activity motion, pointer gaze, and reduced-motion support.')
