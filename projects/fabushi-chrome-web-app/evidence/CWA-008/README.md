# CWA-008 canonical delivery evidence

## Identity

- Project: `FAB-P0011 / CWA`
- Task: `CWA-008`
- Accepted task main: `e60d40f4a97dcb319515abb2b46ef2845d4eb21b`
- Current canonical main readback: `31fdeca90bc8012e144b3ada00ca439891606e2c` (independent PR #2593 is a descendant)
- Version: Desktop `1.2.64`; Chrome package `0.6.0`
- Recorded: `2026-09-14T09:36:20+08:00`

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

Publish run `34796377000` / job `103830176952` successfully validated the exact-main Chrome
package, manifest version `0.6.0`, content manifest, and SHA-256
`67f8d8fa5e292c45a361f89f68009e5ea175ede83c2b4d088f42498b66f8b117`. It then stopped before
calling the Web Store API because the protected `chrome-webstore` environment had empty
publisher, item, OAuth client, client secret, and refresh-token values. No store upload or
review submission occurred. Redacted failure evidence is retained in artifact `10329509377`
([artifact](https://github.com/bhrumom/fabushi/actions/runs/34796377000/artifacts/10329509377)).

## Remaining acceptance

- Live signed-in Chrome crash/error-page, stale, no-link recovery, attachment continuity and
  final Work reply → next acceptance journey with labelled screenshots, complete video,
  trace/report/logs.
- Configure the protected Web Store credentials and rerun the publish workflow with source SHA
  `e60d40f4a97dcb319515abb2b46ef2845d4eb21b`.

Passing packaged assertions without the task-specific live evidence bundle must not close CWA-008.
