# M7-DESKTOP-003 — packaged sidebar footer regression follow-up

- Status: IN PROGRESS
- Parent: M7-DESKTOP-003 unified avatar/search/resizable sidebar
- Scope: Electron packaged desktop only

## Acceptance

1. Bottom personal-navigation footer never overlaps or intercepts conversation peer rows.
2. The peer list remains independently scrollable at constrained packaged-window heights.
3. Personal navigation popover remains able to escape the sidebar bounds.
4. Existing packaged Electron surface E2E performs a normal user click on the assistant peer and passes on macOS and Windows.
5. After merge, canonical main macOS Developer ID signing, App Store Connect notarization, stapling and package verification pass.
6. The resulting current-main macOS package is installed and opened on the target Mac, with bundle and nested code identities verified.

## Evidence

See `evidence/M7-DESKTOP-003/2026-08-23-sidebar-footer-overlap.md`.
