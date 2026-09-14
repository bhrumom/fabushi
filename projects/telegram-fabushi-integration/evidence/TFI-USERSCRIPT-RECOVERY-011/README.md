# TFI-USERSCRIPT-RECOVERY-011 evidence index

## Identity

- Project: `FAB-P0001 / TFI`
- Task: `TFI-USERSCRIPT-RECOVERY-011`
- Accepted task parent main: `e60d40f4a97dcb319515abb2b46ef2845d4eb21b`
- Current canonical parent main readback: `31fdeca90bc8012e144b3ada00ca439891606e2c` (independent PR #2593 is a descendant)
- Source main: `579c5204734afe21d366018d4ee16b5c6d3fb6ce`
- Recorded: `2026-09-14T09:36:20+08:00`

## Source delivery

- [Source PR #15](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/15)
- Exact source-main CI: `34794406863` (PASS)
- [Source Release v2.9.20](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.20)

## Parent and packaged delivery

- [Parent PR #2594](https://github.com/bhrumom/fabushi/pull/2594), protected merge queue and
  canonical readback at the accepted parent SHA.
- Chrome package/journey run `34795268685`, artifact `10329366885` ([artifact](https://github.com/bhrumom/fabushi/actions/runs/34795268685/artifacts/10329366885)).
- Electron packaged gate `34795268724`, Native mobile gate `34795268715`, and security/governance
  checks passed for the accepted SHA.
- Post-main run `34796011272`, artifact `10329677521` ([artifact](https://github.com/bhrumom/fabushi/actions/runs/34796011272/artifacts/10329677521)).
- [GitHub Release desktop-1.2.64](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.64),
  target verified as the accepted parent SHA.

## Web Store and live evidence

Publish run `34796377000` / job `103830176952` validated the exact Chrome package but stopped
before the API call because the protected `chrome-webstore` environment had no publisher/item/
OAuth credentials. Redacted evidence is artifact `10329509377`
([artifact](https://github.com/bhrumom/fabushi/actions/runs/34796377000/artifacts/10329509377)).

Live signed-in Chrome evidence is still required for crash/error-page recovery, no-link manual
recovery, attachment continuity, and final Work reply handoff to the next acceptance session.
Required retention: labelled checkpoint screenshots, complete journey video, trace, report and
diagnostic logs tied to the exact installed version and timestamp.
