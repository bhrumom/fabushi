# CWA-008 canonical delivery evidence

## Identity

- Project: `FAB-P0011 / CWA`
- Task: `CWA-008`
- Accepted task main: `e60d40f4a97dcb319515abb2b46ef2845d4eb21b`
- Current canonical main readback: `6d9fc672f8163b1a4246e46e59691d0110ee9f0b` (descendant of the accepted task SHA)
- Version: Desktop `1.2.64`; Chrome package `0.6.0`
- Recorded: `2026-09-14T11:44:35+08:00`

## Verified CI and Release

| Surface | Run / job | Result | Evidence |
|---|---|---|---|
| Chrome package and journey | run `34795268685`; artifact `10329366885` | PASS | [artifact](https://github.com/bhrumom/fabushi/actions/runs/34795268685/artifacts/10329366885) |
| Electron packaged user journeys | run `34795268724` | PASS | [workflow](https://github.com/bhrumom/fabushi/actions/runs/34795268724) |
| Native Android/iOS | run `34795268715` | PASS | [workflow](https://github.com/bhrumom/fabushi/actions/runs/34795268715) |
| Computer-control security | run `34795268693` | PASS | [workflow](https://github.com/bhrumom/fabushi/actions/runs/34795268693) |
| Post-main delivery | run `34796011272`; job `103829791736`; artifact `10329677521` | PASS | [workflow](https://github.com/bhrumom/fabushi/actions/runs/34796011272), [artifact](https://github.com/bhrumom/fabushi/actions/runs/34796011272/artifacts/10329677521) |
| GitHub Release | `desktop-1.2.64` | PASS | [Release](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.64) |

The post-main artifact is retained for 90 days and contains the exact-source desktop assets and
Chrome evidence. The Release target and `latest` pointer were read back against the accepted SHA.

## External Web Store delivery

The protected `chrome-web-store` environment is configured and the Google Cloud Chrome Web
Store API is enabled. Both workflow attempts validated the exact-main package before the API
failure: version `0.6.0`, content manifest, and SHA-256
`67f8d8fa5e292c45a361f89f68009e5ea175ede83c2b4d088f42498b66f8b117`.

| Attempt | Result | Evidence |
|---|---|---|
| `34802232279` / job `103847044804` | API returned 403 because the Google API was not yet enabled; no store mutation | [workflow](https://github.com/bhrumom/fabushi/actions/runs/34802232279), [artifact](https://github.com/bhrumom/fabushi/actions/runs/34802232279/artifacts/10331873115) |
| `34802669055` / job `103848315174` | Package validation passed; upload returned HTTP 400. Dashboard inspection showed the existing draft already contained `0.6.0` | [workflow](https://github.com/bhrumom/fabushi/actions/runs/34802669055), [artifact](https://github.com/bhrumom/fabushi/actions/runs/34802669055/artifacts/10332215035) |
| Chrome Web Store Developer Dashboard | Existing Fabushi draft `llmojojkgjmaajkklobkfecelcgljhob`, version `0.6.0`, submitted successfully; current UI state is `待审核` | live UI readback at `2026-09-14T11:44:35+08:00` |

The dashboard warns that the broad host permission may require deeper review. The submission
is not yet publicly `PUBLISHED`; the review must finish before public listing/install evidence
can be recorded. The HTTP 400 is treated as a likely duplicate-existing-draft condition based
on the API failure plus the dashboard's existing `0.6.0` draft, not as a successful upload.

## Remaining acceptance

- Live signed-in Chrome crash/error-page, stale, no-link recovery, attachment continuity and
  final Work reply → next acceptance journey with labelled screenshots, complete video,
  trace/report/logs.
- Await external Web Store review, then verify the public listing, install/update path and
  exact package version. The automated publish workflow still needs an idempotent existing-draft
  path before it can safely be used for this item again.

Passing packaged assertions without the task-specific live evidence bundle must not close CWA-008.
