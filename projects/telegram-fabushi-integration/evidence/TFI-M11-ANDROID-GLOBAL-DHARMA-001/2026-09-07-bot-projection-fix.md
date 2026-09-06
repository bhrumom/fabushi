# 2026-09-07 Android packaged Bot projection repair

- Triggering packaged run: `34048304925`
- Triggering source SHA: `8595a50196309c8ebb91c3f8077125d7dc9e3ffa`
- Triggering App-owned device: `gha-34048304925-1-interactive` (offline; not reusable)
- Triggering artifact: `9994017895` (`android-interactive-app-e2e-34048304925-1`)
- Implementation baseline: `main@c82b29cd6404c2f19b93d8479b2e2cae45469249`
- Branch: `fix/tfi-android-bot-installed-projection-20260907`
- State: IMPLEMENTING

## Verified failure boundary

The packaged UI completed `feature.plugin.install`, but Android Messenger refresh then re-posted local install pointers to `/v1/marketplace/plugins/{id}/add` before reading `/v1/marketplace/added`. Any account/manifest/projection failure therefore collapsed the whole refresh into generic `Bot 加载失败`; later semantic actions also observed stale generations. The existing artifact does not retain the exact original HTTP status/body, so that value remains unavailable rather than inferred.

The repair makes Messenger installed-Bot refresh a pure `/v1/marketplace/added` read. The install flow owns `/add` plus read-back confirmation. Only validated canonical projections are retained in an in-process fallback cache; refresh errors preserve the last validated projection and expose bounded diagnostic text.

## Evidence state

- Commit: PENDING
- Pull request: PENDING
- PR contract run/job: PENDING
- PR contract artifact: PENDING
- Protected merge: PENDING
- New Android release/run/device: PENDING
- Full journey screenshots/video/trace/report: PENDING
