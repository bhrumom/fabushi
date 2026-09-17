# MSR-403 — Mahayana CLI device auto-registration and one-line installers

Status: passed
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

## Final closure round — 2026-09-17

- Canonical control/main after installer repair is `aa1063891ebc66111042c40b0602856add6c9bc0` (PR #2693). The exact released Mahayana CLI payload is `38eb8312776ee35d18a5807a5e799aa22cc7a764`; `git diff --quiet 38eb831... aa106389... -- third_party/mahayana` proves the CLI payload tree is unchanged across the installer-only closeout commit.
- No-test package run `35186579174` succeeded for Linux x86_64/aarch64, macOS x86_64/aarch64, and Windows x86_64, then published immutable protected-main channel `mahayana-cli-main-38eb8312776e` with all five platform assets plus `SHA256SUMS.txt` targeting exact payload source `38eb8312776ee35d18a5807a5e799aa22cc7a764`.
- Protected-main official-site deployment run `35194816512` succeeded. Public `install.sh` and `install.ps1` were byte-identical to canonical main after deployment (SHA-256 `fcb6a8ea59891bb2b0472fe260d319c7b788d0b61dc565af612aea363e260815` and `0ba21ddce4432f4b4d04bcca33a398103e86670022840afefc929c67044cb1f4`).
- Final manual released-installer run `35195155342` used expected package source `38eb8312776ee35d18a5807a5e799aa22cc7a764` from control workflow main `aa1063891ebc66111042c40b0602856add6c9bc0`. Linux, macOS, and Windows all completed public one-line installation, dedicated same-account CI login, automatic post-login device registration, official-MCP hold, remote finish, and cleanup with `success`.
- Official Fabushi MCP discovered all three devices simultaneously: `gha-35195155342-1-interactive` (Linux x86_64), `gha-35195155342-1-macos-app` (macOS arm64), and `gha-35195155342-1-windows-app` (Windows x86_64). All advertised `vps_status`, `run_shell_command`, `write_text_file`, and `ci_session_finish` with the same live tool-schema version.
- Official MCP described the Windows `run_shell_command` schema, returned `ephemeral=true` from Windows `vps_status`, remotely executed `mahayana --version` with marker `MSR403_38EB_WINDOWS_OK`, and wrote `D:\a\_temp\msr403-final-windows-proof.txt`. Linux and macOS status/shell calls returned `MSR403_FINAL_LINUX_OK` and `MSR403_FINAL_MACOS_OK` with `mahayana 0.1.0` on their native runners.
- `ci_session_finish` succeeded on all three devices; Action run `35195155342` then completed with all three jobs green. A subsequent production official-MCP `list_devices` returned `[]`, proving ephemeral runner devices do not remain as offline account inventory.
- No automated product test/E2E was run as a release gate. The evidence consists of allowed build/package/provenance/site construction plus the explicitly manual official-MCP behavioral validation required by repository policy.

## Acceptance result

- **MSR-403.A:** passed — same-account login/register path proven on Linux/macOS/Windows released installs.
- **MSR-403.B:** passed — official MCP described and called the CLI-owned tool surface, including Windows remote command/write control.
- **MSR-403.C:** passed — login/start registered live devices and remote finish/shutdown removed them from discovery.
- **MSR-403.D:** passed — three GitHub-hosted ephemeral devices used run-scoped identities and disappeared after finish.
- **MSR-403.E:** passed — public shell/PowerShell one-line installers consumed checksum-verified immutable release assets without repository checkout.
- **MSR-403.F:** passed — exact package/run/release lineage plus official-MCP discovery/control evidence is recorded in `evidence/MSR-403/README.md`.

Stable/formal application release policy remains a separate repository-wide release decision and is not implied by closing this CLI task.
