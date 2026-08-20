#!/usr/bin/env python3
from pathlib import Path

component = Path('frontend/apps/web/src/app/host/bot-mark.tsx').read_text(encoding='utf-8')
styles = Path('frontend/apps/web/src/app/host/host.module.css').read_text(encoding='utf-8')
host = Path('frontend/apps/web/src/app/host/host-client.tsx').read_text(encoding='utf-8')

required_component = [
    'function markRhythm(',
    'function canBlink(',
    'const [blinking, setBlinking]',
    'prefers-reduced-motion: reduce',
    'current.x + (next.x - current.x) * 0.42',
    'botMarkAura',
    'botMarkParticles',
]
for marker in required_component:
    if marker not in component:
        raise SystemExit(f'BotMark motion gate: missing living-motion behavior: {marker}')

for forbidden in ['setInterval(() => setPhase', 'setInterval(() =>', '620);']:
    if forbidden in component:
        raise SystemExit(f'BotMark motion gate: synchronized legacy animation returned: {forbidden}')

required_styles = [
    '@keyframes botMarkBreathe',
    '@keyframes botMarkOrbit',
    '@keyframes botMarkGlow',
    '.botMark[data-accent="pulse"]',
    '@media (prefers-reduced-motion: reduce)',
]
for marker in required_styles:
    if marker not in styles:
        raise SystemExit(f'BotMark motion gate: missing CSS motion contract: {marker}')

# Pointer-follow is intentionally reserved for large hero/profile marks. Keeping
# it out of agent-list rows avoids N pointer listeners for a long sidebar.
if 'className={styles.sidebarBotMark}' in host:
    sidebar_region = host[host.find('className={styles.sidebarBotMark}') - 500:host.find('className={styles.sidebarBotMark}') + 500]
    if 'followPointer' in sidebar_region:
        raise SystemExit('BotMark motion gate: sidebar list marks must not attach pointer-follow listeners')

print('BotMark motion gate passed: seeded rhythms, natural blink, ambient CSS motion, reduced-motion support.')
