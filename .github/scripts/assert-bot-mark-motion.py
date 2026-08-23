#!/usr/bin/env python3
from pathlib import Path

component = Path('frontend/apps/web/src/app/host/bot-mark.tsx').read_text(encoding='utf-8')
engine = Path('frontend/apps/web/src/app/host/fabushi-bot-mark-engine.tsx').read_text(encoding='utf-8')
styles = Path('frontend/apps/web/src/app/host/host.module.css').read_text(encoding='utf-8')
host = Path('frontend/apps/web/src/app/host/host-client.tsx').read_text(encoding='utf-8')

required_component = [
    'FabushiBotMarkEngine',
    'data-engine="fabushi-motion-v2"',
    'fabushiRhythmForBot',
    'botMarkAura',
    'botMarkParticles',
]
for marker in required_component:
    if marker not in component:
        raise SystemExit(f'BotMark motion gate: missing Fabushi v2 integration: {marker}')

required_engine = [
    'const frameListeners = new Set<FrameListener>()',
    'window.requestAnimationFrame(runMotionFrame)',
    'function springStep(',
    'function eyeLensPath(',
    'function profileForState(',
    'IntersectionObserver',
    'prefers-reduced-motion: reduce',
    'queuedSecondBlink',
    'data-engine="fabushi-motion-v2"',
    'surfaceGradientRef',
    'radarSweepRef',
]
for marker in required_engine:
    if marker not in engine:
        raise SystemExit(f'BotMark motion gate: missing Fabushi engine capability: {marker}')

for semantic_state in ['tool-running', 'speaking', 'result', 'error']:
    if f'\"{semantic_state}\"' not in component or f'\"{semantic_state}\"' not in engine:
        raise SystemExit(f'BotMark motion gate: missing Agent lifecycle state: {semantic_state}')

for forbidden in ['GrokBotMarkEngine', 'grok-bot-mark-engine', 'setInterval(() =>']:
    if forbidden in component or forbidden in engine:
        raise SystemExit(f'BotMark motion gate: legacy/copied motion engine returned: {forbidden}')

required_styles = [
    '.botMark[data-accent="pulse"]',
    '@keyframes botMarkOrbit',
    '@keyframes botMarkGlow',
    '@media (prefers-reduced-motion: reduce)',
    'animation: none !important;',
]
for marker in required_styles:
    if marker not in styles:
        raise SystemExit(f'BotMark motion gate: missing ambient CSS contract: {marker}')

# Pointer-follow is intentionally reserved for large hero/profile marks. Keeping
# it out of agent-list rows avoids N pointer listeners for a long sidebar.
if 'className={styles.sidebarBotMark}' in host:
    sidebar_region = host[host.find('className={styles.sidebarBotMark}') - 500:host.find('className={styles.sidebarBotMark}') + 500]
    if 'followPointer' in sidebar_region:
        raise SystemExit('BotMark motion gate: sidebar list marks must not attach pointer-follow listeners')

print('BotMark motion gate passed: Fabushi v2 shared clock, spring physics, expressive eyes, and reduced-motion support.')
