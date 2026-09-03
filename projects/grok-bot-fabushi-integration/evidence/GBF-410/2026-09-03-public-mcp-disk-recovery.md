# 2026-09-03 — public Fabushi MCP OAuth / connector recovery

## Symptom

During the real macOS product-review round, the selected ChatGPT `fabushi test` connector could not complete account discovery. Connector calls returned an account-connection 400. The public `/health` and OAuth metadata GET endpoints were reachable, but a direct standards-compliant dynamic client registration probe (`POST /oauth/register`) returned HTTP 502.

## Root cause evidence

The `bhrum2` host backing the public Fabushi MCP was online, but its root filesystem had reached 100% usage. The remote MCP persists OAuth/DCR state on that host, so write-required OAuth operations failed while read-only health/metadata endpoints could still answer.

No MCP state, account database, active Docker container, Docker volume, or user credential was deleted during recovery.

## Recovery actions

Using the already-authenticated server session, only reclaimable operational data was removed:

- vacuumed archived systemd journals to a bounded recent/size window;
- cleaned apt cache;
- removed old Fabushi temporary directories and transient Node compile cache;
- pruned Docker build cache and unused images only; active containers and volumes were preserved.

The journal vacuum alone reclaimed roughly 845.6 MiB. After the full bounded cleanup, the root filesystem had about 2.2 GiB free (96% used instead of 100%).

## Post-recovery acceptance

- `POST https://fabushi-mcp.ombhrum.com/oauth/register` returned HTTP `201` instead of `502`.
- ChatGPT `fabushi test` `fabushi_account` succeeded for account label `fabushi_mcp_ci_test` (account id recorded by the connector, not duplicated here as a credential).
- ChatGPT `fabushi test` `list_devices` succeeded and returned an empty device list, which is expected while no same-account Fabushi test client is currently online.

## Remaining live acceptance

The connector service/account handshake is recovered. Final GBF-410 acceptance still requires the newly signed Mac test client to log into the same protected test account, register online, appear in `list_devices`, and complete a real read/control journey through `fabushi test`.
