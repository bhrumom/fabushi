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

## 2026-09-17 canonical-main + production gateway proof

- PR #2683 entered the protected merge queue and merged as canonical `main` commit `c70eba65f38cd61c3cf6c5412868f7a1b92df4dd`; its merge-group CI run `35173253639` passed.
- The production official MCP on `bhrum2` was atomically advanced from the prior release to `/opt/fabushi-remote-mcp/releases/c70eba65f38cd61c3cf6c5412868f7a1b92df4dd`. The deployed `device-gateway.js` SHA-256 is `6c7552dd25d913a67e59046abcca5e64f8124f9b76072b779e663158eafe2a7f` and `fabushi-remote-mcp-server.js` SHA-256 is `72037681922a87e99f3fa2b7c0eee5a62b9514fb69a5048e0f0544a9804bef93`, matching canonical main.
- Local `127.0.0.1:8792/health` and public `https://fabushi-mcp.ombhrum.com/health` both returned the healthy `fabushi-device-control-mcp` service. Existing ChatGPT OAuth remained valid: `fabushi_account` resolved the dedicated CI account after restart.
- Exact-main manual live-device Action run `35173406319` on `c70eba65f38cd61c3cf6c5412868f7a1b92df4dd` completed successfully.
- Official MCP discovered `gha-35173406319-1-interactive` online with metadata SHA `c70eba65f38cd61c3cf6c5412868f7a1b92df4dd` and the four expected capabilities. `describe_device_tool(vps_status)` succeeded; `device_call(vps_status,{})` returned Linux/x86_64 and `ephemeral=true`; remote shell returned `MAHAYANA_CANONICAL_MAIN_OK`; bounded file write succeeded.
- Official MCP `ci_session_finish` completed, the Action exited successfully, and a subsequent production `list_devices` returned an empty array. This proves the GitHub-hosted runner is removed from discoverable account devices after disconnect rather than lingering as an offline device.
- The protected-main site deployment published `https://ombhrum.com/mahayana/install.sh` and `install.ps1`; both returned HTTP 200 and byte-for-byte SHA-256 matches to canonical main (`285e4c1b59dd75d3bfd03985771d055982379022d23834e1fdbb89faeb59cfd9` and `9a3d1a09f62f9616839d2397bbc9fcc0ae6445a50546b2d7c0dc003f25bba084`).
- Site deployment run `35173289291` deployed the assets successfully but failed only its final legacy-host verifier because `fabushi.ombhrum.com` is a healthy in-place Cloudflare custom domain rather than an HTTP redirect to `ombhrum.com`. The follow-up fixes that assertion; package/latest-channel and successful site-verifier evidence are still pending before task closure.

## 2026-09-17 final multi-platform released-installer proof

- Windows runtime repair PRs were merged through protected main before final validation: #2689 bounded the original external liveness probe, #2692 replaced Windows liveness with native process queries, and #2693 removed the redundant pre-login `device start` from public installers so same-account registration starts only after login. Immutable-release/channel work was delivered through #2690/#2691.
- Exact released CLI payload source: `38eb8312776ee35d18a5807a5e799aa22cc7a764`.
- No-test multi-platform package run: `35186579174` — Linux x86_64/aarch64, macOS x86_64/aarch64, Windows x86_64, and immutable publish job all concluded `success`.
- Immutable installer release: `mahayana-cli-main-38eb8312776e`, targeting exact payload source `38eb8312776ee35d18a5807a5e799aa22cc7a764`, with all five platform packages and `SHA256SUMS.txt`.
- Final installer-control main: `aa1063891ebc66111042c40b0602856add6c9bc0`. `third_party/mahayana` has zero diff between payload source `38eb831...` and this control commit; the only final delta needed for validation is installer behavior.
- Official-site deployment run `35194816512` concluded `success`. Live public installer hashes matched canonical main: `install.sh` = `fcb6a8ea59891bb2b0472fe260d319c7b788d0b61dc565af612aea363e260815`; `install.ps1` = `0ba21ddce4432f4b4d04bcca33a398103e86670022840afefc929c67044cb1f4`.
- Final manual released-installer Action run `35195155342` used expected package source `38eb8312776ee35d18a5807a5e799aa22cc7a764`; all three jobs — Linux, macOS ARM64 and Windows x86_64 — concluded `success` after public one-line installation, dedicated same-account login, automatic CLI device registration, official-MCP validation, remote finish and cleanup.
- Official MCP simultaneously returned three live devices: `gha-35195155342-1-interactive`, `gha-35195155342-1-macos-app`, and `gha-35195155342-1-windows-app`, each advertising `vps_status`, `run_shell_command`, `write_text_file`, and `ci_session_finish`.
- Official MCP `describe_device_tool(run_shell_command)` succeeded on Windows. Windows `vps_status` returned platform `windows`, arch `x86_64`, `ephemeral=true`; remote shell returned `MSR403_38EB_WINDOWS_OK`, `mahayana 0.1.0`, and Windows NT `10.0.26100.0`; bounded `write_text_file` created `D:\a\_temp\msr403-final-windows-proof.txt`.
- Linux official-MCP status returned `linux/x86_64`, `ephemeral=true`; shell returned `MSR403_FINAL_LINUX_OK`, `mahayana 0.1.0`, and the GitHub-hosted Linux kernel identity.
- macOS official-MCP status returned `macos/aarch64`, `ephemeral=true`; shell returned `MSR403_FINAL_MACOS_OK`, `mahayana 0.1.0`, and Darwin arm64 identity.
- `ci_session_finish` succeeded on all three device IDs. After Action run `35195155342` completed, production official-MCP `list_devices` returned `[]`. This is the final proof that ephemeral runners disappear rather than persisting as offline device inventory.
- No passwords, tokens, refresh credentials, API keys, or other secrets are stored here. No automated product tests/E2E were used as a release gate; package/site construction and manual official-MCP behavior validation followed the repository release policy.
