# TFI-USERSCRIPT-RECOVERY-011 evidence index

## Identity

- Project: `FAB-P0001 / TFI`
- Task: `TFI-USERSCRIPT-RECOVERY-011`
- Accepted task parent main: `e60d40f4a97dcb319515abb2b46ef2845d4eb21b`
- Current canonical parent main readback: `387ae731c3677d9d3023d400f1da60d7ac958a4f` (records PR #2603 merged through the protected queue; descendant of the accepted task SHA)
- Source main: `579c5204734afe21d366018d4ee16b5c6d3fb6ce`
- Recorded: `2026-09-14T11:44:35+08:00`

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

Chrome Web Store protected credentials are configured and the API is enabled. Publish retries
`34802232279` (pre-enable HTTP 403; artifact `10331873115`) and `34802669055` (package
validation passed, upload HTTP 400; artifact `10332215035`) are retained. The signed-in
Developer Dashboard showed existing Fabushi draft `llmojojkgjmaajkklobkfecelcgljhob` at
version `0.6.0`; submitting that existing draft succeeded and the UI readback at
`2026-09-14T11:44:35+08:00` is `待审核`. The broad `<all_urls>` host permission may require
deeper review, so this is not yet public `PUBLISHED`. The automated workflow still needs an
idempotent existing-draft path.

Live signed-in Chrome evidence is still required for crash/error-page recovery, no-link manual
recovery, attachment continuity, and final Work reply handoff to the next acceptance session.
Required retention: labelled checkpoint screenshots, complete journey video, trace, report and
diagnostic logs tied to the exact installed version and timestamp.
