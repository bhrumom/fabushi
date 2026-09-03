# 2026-08-25 — Bot avatar switching + right info panel regression

## User evidence

User supplied a real desktop screenshot and reported two release-blocking regressions:

1. after switching Bot conversations, a Bot avatar can disappear/degrade into text instead of retaining the shared Fabushi Motion v2 avatar;
2. clicking the conversation profile/info action cannot open the right-side info panel.

## Required behavior

- Every peer/Bot keeps one visible canonical `fabushi-motion-v2` BotMark before, during and after conversation switching.
- Workbench state projection may animate the active Bot, but must never leave previously active peer avatars hidden.
- Workbench avatar replacement must preserve the same Bot identity seed as the Messenger BotMark so selecting a Bot does not visually change its identity.
- The right info panel must open at all supported desktop window widths. Wide layouts use the docked third column; narrower layouts use a right overlay/drawer rather than silently disabling the panel.
- Regression coverage must exercise conversation switching and a narrow desktop viewport before release.
