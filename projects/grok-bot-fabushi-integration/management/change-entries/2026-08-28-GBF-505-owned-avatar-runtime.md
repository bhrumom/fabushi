# Change entry — GBF-505 Fabushi-owned avatar runtime

Date: 2026-08-28

## Change

Production BotMark rendering no longer depends on the vendored OpenMaus `CursorAvatar` implementation. A Fabushi-owned procedural SVG runtime now owns geometry, gradients, semantic Agent motion, gaze, imperative actions, pause behavior and reduced-motion handling.

## Migration

- add `fabushi-avatar-runtime.tsx`;
- make `fabushi-bot-mark-engine.tsx` a thin Fabushi runtime adapter;
- delete `openmaus-cursor-avatar.tsx`;
- rename renderer contract to `fabushi-motion-v3` / `fabushi-owned-svg-runtime`;
- make CI reject upstream avatar/compiled-renderer runtime regressions.

## Compatibility

The public `BotMark` props/handle and existing Agent lifecycle states remain stable, so callers do not need a parallel migration.

## Rollback

Revert the GBF-505 PR as one unit. Do not restore an upstream compiled renderer or vendored mascot runtime as a forward fix.
