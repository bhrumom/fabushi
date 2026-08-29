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
runtime = read_repo_text('frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx')
styles = read_repo_text('frontend/apps/web/src/app/host/host.module.css')
host = read_repo_text('frontend/apps/web/src/app/host/host-client.tsx')
identity_aliases = read_repo_text('desktop/src/agent-identity-aliases.ts')
durable_state = read_repo_text('desktop/src/durable-agent-state.ts')
desktop_main = read_repo_text('desktop/src/main.tsx')

required_component = [
    'FabushiBotMarkEngine',
    'data-engine="fabushi-motion-v3"',
    'data-renderer="fabushi-owned-svg-runtime"',
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
]
for marker in required_component:
    if marker not in component:
        raise SystemExit(f'BotMark motion gate: missing Fabushi identity/runtime integration: {marker}')

required_engine = [
    'FabushiAvatarRuntime',
    'FabushiAvatarRuntimeHandle',
    'identity={botId}',
    'state={state}',
    'shape={shape}',
    'color={color}',
    'gaze={normalizedGaze(gazeTarget)}',
    'paused={paused}',
]
for marker in required_engine:
    if marker not in engine:
        raise SystemExit(f'BotMark motion gate: missing Fabushi avatar adapter behavior: {marker}')

required_runtime = [
    'data-fabushi-avatar-runtime="v1"',
    'requestAnimationFrame(tick)',
    'cancelAnimationFrame(frame)',
    'prefers-reduced-motion: reduce',
    'personaPath(shape)',
    'linearGradient',
    'radialGradient',
    'MOTION: Partial<Record<BotMarkState, MotionProfile>>',
    'actionRef',
    'pointermove',
    'FabushiAvatarRuntimeHandle',
]
for marker in required_runtime:
    if marker not in runtime:
        raise SystemExit(f'BotMark motion gate: Fabushi-owned runtime is incomplete: {marker}')

# These terms identify the retired vendored/runtime paths. They are prohibited
# from the production avatar implementation; documentation/evidence may still
# mention them historically.
forbidden_runtime_terms = [
    'openmaus-cursor-avatar',
    'CursorAvatar',
    'DEFAULT_SILHOUETTE',
    'milind-soni/OpenMausBot',
    'GrokBotMarkEngine',
    'grok-bot-mark-engine',
    'index-UbX-y3il.js',
    'checksum-pinned-artifact-runtime',
    'shipped renderer',
]
for term in forbidden_runtime_terms:
    if term in component or term in engine or term in runtime:
        raise SystemExit(f'BotMark motion gate: retired upstream runtime dependency returned: {term}')

retired_path = Path('frontend/apps/web/src/app/host/openmaus-cursor-avatar.tsx')
if retired_path.exists():
    raise SystemExit('BotMark motion gate: vendored OpenMaus avatar source must not exist')

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
        raise SystemExit(f'BotMark motion gate: desktop bootstrap skipped identity/durability stage: {bootstrap_marker}')

for semantic_state in ['tool-running', 'speaking', 'result', 'error']:
    if f'"{semantic_state}"' not in component:
        raise SystemExit(f'BotMark motion gate: missing Fabushi Agent lifecycle state: {semantic_state}')

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

print('BotMark motion gate passed: Fabushi-owned procedural SVG runtime, semantic Agent states, canonical identity, visibility pause, reduced-motion, and no upstream avatar/renderer dependency.')
