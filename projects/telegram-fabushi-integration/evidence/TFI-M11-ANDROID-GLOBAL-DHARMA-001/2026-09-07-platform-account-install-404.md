# Android 1.2.52 packaged account-install route failure and canonical repair

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M11-ANDROID-GLOBAL-DHARMA-001`
- Released source: `main@380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab`
- Release: `android-v1.2.52-262491811`
- Release run/job: `34050780156` / `101533889951`
- Release artifact: `9994614114` (`native-android-github-1.2.52-262491811`)
- Packaged E2E run/job: `34051316405` / `101535343430`
- Fresh App-owned device: `gha-34051316405-1-interactive`

## Real packaged failure

The released app reached Marketplace, searched `全球法布施`, and exposed the canonical `global-dharma` result. The installed-Mini-App Bot refresh then surfaced the exact production control-plane failure:

- `GET /v1/marketplace/added -> HTTP 404 Not Found`
- after invoking `install-global-dharma`, `host-status` became `安装未完成：Fabushi platform request failed: POST /v1/marketplace/plugins/global-dharma/add -> HTTP 404 Not Found`

This is post-fix evidence that Android no longer hides the projection failure or falsely calls install successful.

## Root boundary

`api.ombhrum.com` forwards all `/v1/*` traffic to the canonical Rust `mahayana-platform` Worker. That Worker registered public marketplace browse/release endpoints but did not register account install/read endpoints, and PLATFORM_DB had no account Marketplace install ledger. The legacy Node marketplace implementation therefore cannot be treated as production authority.

## Repair decision

- add one PLATFORM_DB account install ledger keyed by authenticated Mahayana `user_id` + `plugin_id`;
- add one data-driven plugin projection table, seeded from the existing official Global Dharma manifest Bot/menu identity;
- add authenticated `POST /v1/marketplace/plugins/:plugin_id/add` and read-only `GET /v1/marketplace/added` to the canonical Rust Worker;
- keep account credentials in the existing auth boundary; no token/session data is persisted in the install ledger;
- production smoke requires both direct Worker and public gateway account routes to exist and fail closed with HTTP 401 when unauthenticated.

## Open-source / official-source startup gate

Reviewed before commit:

- Cloudflare D1 official migration documentation (`developers.cloudflare.com/d1/reference/migrations/`): migrations are versioned SQL files applied sequentially and recorded by D1.
- Cloudflare D1 foreign-key documentation (`developers.cloudflare.com/d1/sql-api/foreign-keys/`): D1 enforces foreign-key constraints for queries and migrations.
- Cloudflare D1 SQL documentation (`developers.cloudflare.com/d1/sql-api/sql-statements/`): D1 uses SQLite-compatible SQL semantics, including the upsert pattern already used in this repository.
- Cloudflare `workers-rs` (`github.com/cloudflare/workers-rs`, MIT OR Apache-2.0): reviewed current Rust Worker/D1 routing conventions; the repository already uses the same `worker::Router` and D1 binding APIs.

Decision: reuse the repository's existing `workers-rs`/D1 architecture and Cloudflare-native migration mechanism. No new dependency or copied third-party implementation is introduced.

## Failing packaged evidence retained

Run `34051316405` completed `failure` and always-upload produced artifact `9994884584` (`android-interactive-app-e2e-34051316405-1`, 22,594,287 bytes). The archive contains:

- `steps/001-app-installed.png` through `steps/022-fabushi.app.wait.png` plus `steps/999-final.png`;
- `device-gateway-trace.jsonl`;
- `report.json` (`status=failed-timeout`, `deviceId=gha-34051316405-1-interactive`, source/release SHA `380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab`);
- `logcat-final.txt` and `logcat-live.txt`;
- native recording segments under `video/segment-*.mp4` plus `video/concat.txt`.

Authenticated artifact archive endpoint: `https://api.github.com/repos/bhrumom/fabushi/actions/artifacts/9994884584/zip`. A single post-fix acceptance video is still PENDING and must come from the strictly newer exact-main rerun after the service repair.
