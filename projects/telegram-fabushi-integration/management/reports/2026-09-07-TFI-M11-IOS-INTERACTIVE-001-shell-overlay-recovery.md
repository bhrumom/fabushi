# TFI-M11-IOS-INTERACTIVE-001 — shell-overlay recovery round

Status: `IN_PROGRESS`

Canonical failure: `dca0fea5f93567df3928b9a3ee14855ed0da2c67`, Native mobile `34056507262`, iOS job `101549283506`, xcresult artifact `9996206512`.

The previous coordinate fallback closed the visible remote surface by hitting the overlaying Grok shell back control. The next Marketplace step therefore started from Grok home, not `app-shell`. This round removes non-hittable coordinate taps and makes Marketplace navigation recover/verify the legacy workbench first. The existing remote-surface disappearance assertion remains unchanged.

Validation is not complete until protected merge, new canonical Native mobile, exact-main post-main, and latest-SHA packaged iOS/Android evidence are present. Missing evidence remains `PENDING`.
