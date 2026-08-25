# M7-DESKTOP-004 evidence index

## Implementation evidence

- Branch: `fix/tfi-bot-avatar-info-panel`
- Product files: `desktop/src/mahayana-agent-workbench.tsx`, `desktop/src/messaging-shell-v2.tsx`, `desktop/src/messaging-shell.module.css`
- Regression: `desktop/e2e/messenger-regressions.spec.ts`
- User screenshot requirement: `source/2026-08-25-bot-avatar-info-panel-regression.md`

## Pending release evidence

Record final PR/head checks, protected merge SHA, canonical-main packaged E2E visual artifacts and the new Release tag/target/assets after they are produced.


## Exact-main failure evidence — selected-peer identity

- Canonical main: `6ae21cba7878d113ac2902df94d867e7d3b7cd34`.
- Electron delivery: `32813752100`.
- Linux real-Host diagnostics: artifact `9550721736`.
- Failure: selected peer `peer:bot:incident-bot`; Header semantic Motion v2 identity `peer:conversation:codex:agent:assistant`.
- This evidence blocks Release and is treated as a product failure, not a waived assertion.

## Follow-up implementation

- Branch: `fix/tfi-selected-peer-avatar-identity`.
- Identity authority: active peer row direct semantic BotMark.
- React portal state now includes selected `activeBotId` + label; runtime task state remains independent.
- Regression covers first → second → first peer Header identity and 1100px overlay info-panel identity.
- Open-source-first reference: official `facebook/react` (MIT) portal/reconciliation design; architectural principle adapted, no source copied.

## Pending closure

Record protected merge SHA, final exact-main Electron/native runs, retained screenshot/video/trace/report artifact IDs, Release tag, target commit and updater assets only after they exist.


## Exact-main failure evidence — class-only peer selection

- Canonical main: `eb4b340ce4d9d18cc69b4e60ec97037cbcb2c878`.
- Electron delivery: `32822744019`.
- Linux real-Host diagnostics: `9553768019`.
- Result: 17/18 E2E passed; selected peer row switched to Incident Bot but Header portal identity remained the previous assistant at assertion time.
- Root cause: peer selection is a CSS class mutation on reused DOM rows; the existing portal MutationObserver watched only child-list mutations.
- Follow-up: observer now includes `attributes: true`, `attributeFilter: ['class']`, and refreshes only when a changed class belongs to a Messenger peer button; recovery polling is retained but no longer the normal switch path.
