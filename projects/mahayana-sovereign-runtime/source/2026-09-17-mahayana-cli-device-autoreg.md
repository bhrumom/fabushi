# 2026-09-17 — Mahayana CLI one-line install + same-account device auto-registration

## Original user requirement
- Install Mahayana CLI on a machine, sign in with the same Fabushi test/account identity used by the official Fabushi MCP, and verify that the official MCP can discover and control that machine.
- If discovery fails, repair the CLI so an installed and signed-in CLI automatically exposes the installed machine as a controllable Fabushi device without a second manual agent setup.
- Provide a one-line standalone installer experience comparable to Codex CLI:
  - macOS/Linux: `curl -fsSL <official>/install.sh | sh`
  - Windows: `powershell -ExecutionPolicy ByPass -c "irm <official>/install.ps1 | iex"`
- GitHub Actions runners and other temporary machines are ephemeral devices: they must be discoverable while online and disappear after disconnect/TTL, without remaining in the account device list.
- The official Fabushi MCP is the same-account discovery/control plane: every installed Fabushi product surface that signs into the same account and advertises a supported device tool surface should become controllable through that MCP while live.

## Acceptance intent
1. CLI installation is standalone and does not require cloning the repository.
2. Successful CLI login automatically starts/maintains device registration for the same Fabushi account.
3. Logout stops registration and removes the live device from official MCP discovery.
4. Persistent machines use a stable installation/device identity but are only listed while connected.
5. CI/runner devices use explicit ephemeral identity/lifetime and leave no persistent account-list residue after disconnect/expiry.
6. Official MCP `fabushi_account -> list_devices -> describe_device_tool -> device_call` works against the installed CLI device.
7. macOS/Linux and Windows installer entrypoints resolve signed/released platform artifacts and install `mahayana` onto PATH.

This source is additive to the project source of truth and does not weaken repository-wide release/test policy.
