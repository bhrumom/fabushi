# MSR-403 evidence

## 2026-09-17 branch runtime proof

- Pull request: #2683 (`feat/msr-403-mahayana-device-autoreg`).
- Exact validated branch source: `e9a696941a05ca1b66a8a56b8a7557c6aec0f7f3`.
- Manual GitHub Actions live-device run: `35172684311`.
- The run built the standalone Mahayana CLI without product tests, logged in through the dedicated Fabushi CI test account, started the CLI-owned device agent, registered it with the official gateway, held it for remote validation, and completed successfully.
- Official Fabushi MCP account used for validation: label `fabushi_mcp_ci_test`; numeric account id is intentionally not persisted in this repository record.
- Official MCP discovered device `gha-35172684311-1-interactive` as online with source metadata `e9a696941a05ca1b66a8a56b8a7557c6aec0f7f3` and capabilities `vps_status`, `run_shell_command`, `write_text_file`, `ci_session_finish`.
- `describe_device_tool(vps_status)` returned the advertised live schema.
- `device_call(vps_status,{})` returned Linux/x86_64, `ephemeral=true`, and the exact `gha-35172684311-1-interactive` identity.
- `device_call(run_shell_command, ...)` executed a harmless remote command and returned `MAHAYANA_REMOTE_OK` plus the GitHub-hosted runner kernel identity.
- `device_call(write_text_file, ...)` wrote `/tmp/mahayana-official-mcp-proof.txt` successfully.
- After the runner stopped, the currently deployed production gateway still returned this runner as `offline`. This is expected evidence of the production gap that #2683's live-only gateway change closes. Therefore canonical-main merge + production gateway deployment + exact-main rerun are still required before MSR-403 can be marked passed.

No passwords, account tokens, refresh credentials, or other secrets are stored in this evidence record.
