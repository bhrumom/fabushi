# MSR-205 — Bot discovery/control of installed MiniApps through one tool-policy plane

- Project: `FAB-P0005 / MSR`
- Task ID: `MSR-205`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `2`
- Risk: high; extension discovery + permission routing

## Single objective

Expose only the current account's installed MiniApps as Mahayana capabilities and execute them through the existing tool/policy/approval bus with install/version/permission fencing.

## Dependencies

`MSR-204`, TFI `M8-BIND-001`, and existing MSR-401 extension-stack concepts.

## Exact implementation allowlist

- `third_party/mahayana/mahayana-rs/mahayana-kernel/src/extension.rs`
- `third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-platform-client/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs`
- `third_party/mahayana/mahayana-rs/mahayana-cli/src/main.rs`
- `projects/mahayana-sovereign-runtime/evidence/MSR-205/**`

Forbidden: MiniApp ownership/account-sync implementation, renderer UI, device-control transport, second plugin/MCP runtime, workflows/version files.

## Acceptance

1. Capability discovery returns only installed/current-account MiniApps and stable tool metadata derived from the canonical install/manifest.
2. Mutating execution requires `mini_app_install_id + manifest_digest + permission_revision + Bot session id/generation` in ToolExecutionContext.
3. Uninstall, update digest change, permission revocation or stale Bot generation immediately invalidates stale capability refs/calls.
4. MiniApp calls reuse Mahayana policy/approval/audit and existing WebMCP/App MCP/MiniApp bridge; no second execution bus.
5. CLI can list/describe/call an installed MiniApp using the same contracts used by Bots.
6. Tests cover cross-account denial, stale install/digest/revision, approval denial, uninstall race and successful read/write calls.

## Rollback

Disable MiniApp capability projection; canonical installs remain intact. Never preserve stale callable refs after rollback or permission revocation.
