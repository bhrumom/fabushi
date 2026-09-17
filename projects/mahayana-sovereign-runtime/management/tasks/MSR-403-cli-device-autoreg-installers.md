# MSR-403 — Mahayana CLI device auto-registration and one-line installers

Status: in-progress
Task ID: `MSR-403`
Source: `source/2026-09-17-mahayana-cli-device-autoreg.md`

## Objective
Make the standalone Mahayana CLI an install-and-sign-in Fabushi device surface: after authentication it automatically registers a controllable same-account device with the official Fabushi MCP, supports ephemeral runner lifetime, and can be installed with official one-line macOS/Linux or Windows bootstrap commands.

## Atomic acceptance criteria
- **MSR-403.A — Same-account registration:** CLI derives a bounded device credential from the existing Mahayana/Fabushi account session and registers only to the official gateway for that account.
- **MSR-403.B — Tool surface:** CLI device advertises the supported non-sensitive computer/command tool schema and official MCP can describe/call it.
- **MSR-403.C — Lifecycle:** login/start brings registration online; logout/shutdown disconnects; no offline historical device is returned by `list_devices`.
- **MSR-403.D — Ephemeral runners:** `GITHUB_ACTIONS`/explicit ephemeral mode uses run-scoped identity and TTL; disconnected/expired runner entries disappear rather than becoming persistent account inventory.
- **MSR-403.E — One-line install:** official `install.sh` and `install.ps1` download release metadata/artifacts, verify integrity when metadata provides a digest, install the `mahayana` executable on PATH, and do not require repository checkout.
- **MSR-403.F — Exact evidence:** GitHub Actions checks/builds the changed Rust/installer paths; exact released artifact is installed on a fresh device, test account login succeeds, and official MCP proves discovery + a harmless control call. Stable release remains blocked unless repository release policy is separately satisfied.

## Verification method
No local builds/tests. Use source inspection locally, GitHub Actions for compile/test/package verification, then official Fabushi MCP against the exact installed artifact/device.

## Current round
- Official MCP account authentication is healthy but `list_devices` currently returns zero devices.
- `bhrum2` is available through the legacy/unified control plane and will be used only as the installation/repair host until the new CLI-owned device appears in the official MCP.
- Implementation and exact-device acceptance are in progress.
