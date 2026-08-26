#!/usr/bin/env python3
from pathlib import Path
import subprocess


def read_repo_text(path: str) -> str:
    file_path = Path(path)
    if file_path.exists():
        return file_path.read_text(encoding='utf-8')
    result = subprocess.run(
        ['git', 'show', f'HEAD:{path}'],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding='utf-8',
    )
    return result.stdout


component = read_repo_text('frontend/apps/web/src/app/host/bot-mark.tsx')
engine = read_repo_text('frontend/apps/web/src/app/host/fabushi-bot-mark-engine.tsx')
openmaus = read_repo_text('frontend/apps/web/src/app/host/openmaus-cursor-avatar.tsx')
styles = read_repo_text('frontend/apps/web/src/app/host/host.module.css')
host = read_repo_text('frontend/apps/web/src/app/host/host-client.tsx')
identity_aliases = read_repo_text('desktop/src/agent-identity-aliases.ts')
durable_state = read_repo_text('desktop/src/durable-agent-state.ts')
desktop_main = read_repo_text('desktop/src/main.tsx')

required_component = [
    'FabushiBotMarkEngine',
    'data-engine="fabushi-motion-v2"',
    'data-renderer="openmaus-unified-mark"',
    'data-motion-tier={botMarkMotionTier(state, emphasis, followPointer)}',
    'AMBIENT_MOTION_STATES',
    'canonicalBotIdentity',
    'registerBotIdentityAliases',
    'useSyncExternalStore(subscribeBotIdentity, botIdentitySnapshot, botIdentitySnapshot)',
    'data-canonical-bot-id={identityId}',
    'botId={identityId}',
    'animated?: boolean',
    'function useAvatarMotionAllowed()',
    'document.visibilityState === "visible"',
    'document.hasFocus()',
    'const effectivePaused = paused || !animated || !motionAllowed',
    'return "blob";',
]
for marker in required_component:
    if marker not in component:
        raise SystemExit(f'BotMark motion gate: missing OpenMaus/Fabushi identity integration: {marker}')

# The normal identity path must never hash Bot IDs into unrelated body shapes.
for forbidden in ['IDENTITY_SHAPES[', 'shapeHash(canonicalBotIdentity', 'shapeHash(value']:
    if forbidden in component:
        raise SystemExit(f'BotMark motion gate: irregular identity-shape lottery returned: {forbidden}')

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
    'CursorAvatar',
    'DEFAULT_SILHOUETTE',
    'OPENMAUS_SILHOUETTE',
    'gradientFor(color)',
    'openMausState(state)',
    '"tool-running": "working"',
    'speaking: "listening"',
    'result: "happy"',
    'error: "alerting"',
    'paused={paused}',
    'effects={!paused}',
    'autoBlink={!paused}',
    'autoExpression={!paused}',
    'milind-soni/OpenMausBot@667af71ae7e93640ba4b1a5f3b38a1ad342025da',
]
for marker in required_engine:
    if marker not in engine:
        raise SystemExit(f'BotMark motion gate: missing OpenMaus wrapper behavior: {marker}')

required_upstream = [
    'SPDX-License-Identifier: Apache-2.0',
    'Vendored from milind-soni/OpenMausBot@667af71ae7e93640ba4b1a5f3b38a1ad342025da',
    'export type CursorState',
    'export const CursorAvatar',
    'prefers-reduced-motion: reduce',
    'if (p.paused)',
    'e.pausedPaint',
    'setTimeout(() =>',
    'requestAnimationFrame(step)',
]
for marker in required_upstream:
    if marker not in openmaus:
        raise SystemExit(f'BotMark motion gate: pinned OpenMaus source/provenance is incomplete: {marker}')

for semantic_state in ['tool-running', 'speaking', 'result', 'error']:
    if f'"{semantic_state}"' not in component:
        raise SystemExit(f'BotMark motion gate: missing Fabushi Agent lifecycle state: {semantic_state}')

for forbidden in ['setInterval(() =>', 'surfaceGradientRef', 'radarSweepRef', 'botMarkParticles']:
    if forbidden in component or forbidden in engine:
        raise SystemExit(f'BotMark motion gate: retired custom visual effect returned: {forbidden}')

required_styles = [
    '.botMark > svg',
    'filter: none;',
    '.onboardingMarkStage > span:not(.onboardingBotMark)',
    '@media (prefers-reduced-motion: reduce)',
    'animation: none !important;',
]
for marker in required_styles:
    if marker not in styles:
        raise SystemExit(f'BotMark motion gate: missing mascot CSS contract: {marker}')

# Pointer-follow is intentionally reserved for large hero/profile marks. Keeping
# it out of agent-list rows avoids N pointer listeners for a long sidebar.
if 'className={styles.sidebarBotMark}' in host:
    sidebar_region = host[host.find('className={styles.sidebarBotMark}') - 500:host.find('className={styles.sidebarBotMark}') + 500]
    if 'followPointer' in sidebar_region:
        raise SystemExit('BotMark motion gate: sidebar list marks must not attach pointer-follow listeners')

print('BotMark motion gate passed: pinned OpenMaus mascot source, unified body geometry, canonical identity, visibility/static pause controls, semantic activity mapping, native durability, and reduced-motion support.')