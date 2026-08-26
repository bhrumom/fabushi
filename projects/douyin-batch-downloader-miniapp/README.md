# Fabushi Douyin Batch Downloader MiniApp

- Project ID: `FAB-P0009`
- Project Key: `DBD`
- Objective: provide a searchable/installable Fabushi MiniApp that batch-resolves user-authorized Douyin shares and downloads the highest-quality watermark-free media to a user-selected local directory.
- Verified status: in progress on `codex/douyin-batch-downloader-miniapp`; no CI, merge, packaged E2E, Release, or marketplace-production evidence yet.
- Current stage / next gate: `DBD-S1-implementation` / PR validation.
- Scope: URL normalization, bounded batch resolution/download, idempotent filenames, manifest/evidence output, marketplace discovery/install, and the requested one-time download of videos shared by “小李子”.
- Non-goals: bypassing access controls, CAPTCHA, private-content authorization, DRM, reposting, or cloud storage of browser cookies.
- Source of truth: [SOURCE_OF_TRUTH.md](SOURCE_OF_TRUTH.md).
- Owner: Fabushi product engineering.
- Acceptance summary: `DBD-REQ-001` through `DBD-REQ-005` in `docs/02-需求与成功指标.md`.

Navigation: `source/`, `docs/`, `management/`, `decisions/`, `evidence/`, and `runbooks/`.
