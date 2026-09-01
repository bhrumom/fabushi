# RDF-001 — Unified device presence vertical slice

- Project ID: FAB-P0009
- Project Key: RDF
- Status: in-progress
- Started/updated: 2026-09-01
- Completed: N/A
- Branch: `codex/rustdesk-fusion-device-presence`
- Commit/PR: pending

## Objective

Extend the existing same-account registration/heartbeat path into a provider-neutral inventory that carries platform, version, normalized remote capabilities and active-session state through the Worker API into the Fabushi device list, with search/filter UI and legacy compatibility.

## Scope

In: D1 additive migration; Worker register/list contracts; Host protocol and FeatureHost mapping; Web API normalization; device list search/filter/details; narrow contract tests and project evidence.

Out: RustDesk wire compatibility, hbbs/hbbr deployment, native RustDesk binaries, new media/file/audio engines.

## Dependencies

Existing account token, device secret, D1 remote tables, FeatureHost transport and remote-computer page.

## Acceptance

1. Same-account device updates cannot cross ownership or bypass device-secret possession.
2. Registration stores validated provider/platform/version/capabilities.
3. Heartbeat updates liveness without overwriting identity/capability fields.
4. List returns online/offline/last seen plus metadata and active session count.
5. Existing clients with no new fields remain valid with safe defaults.
6. Web/mobile list displays and filters normalized inventory.
7. Project governance and narrow Actions checks pass.

## Open-source survey

RustDesk client/server and hbb_common revisions are pinned in `source/README.md`. Reuse: topology, capability taxonomy and behavioral test ideas. Adapt: normalized provider contract. Reject for this slice: copied/linked AGPL implementation or second identity authority.

## Verification/evidence

Pending GitHub Actions and PR. Post-main package/E2E/Release remain required because this affects the product.

## Risks/blockers

AGPL blocks direct embedding until reviewed; native interop is not part of this slice.

## Next action

Implement migration, producer/API/UI contracts and tests; open PR; run the narrowest Actions workflows.
