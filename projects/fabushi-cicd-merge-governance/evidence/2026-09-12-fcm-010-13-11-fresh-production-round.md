# FCM-010.13.11 fresh production evidence — 2026-09-12

## Verdict

The two originally scoped blockers are independently verified as repaired, but the parent production acceptance is still **blocked** because a new semantic-query contract defect stopped the fresh journey in `send`.

Do not mark FCM-010.13.11 or FCM-010.13 passed from this round. Do not run the latency observer yet.

## Source and merge provenance

- Repair PR: #2551.
- Protected merge result / exact canonical source: `c6183ebc1fbe93807d8bb1252171a4d5247a9b27`.
- Electron exact-main gate: run `34680351945`, success.
- Native Android/iOS exact-main gate: run `34680351950`, success.
- Post-main delivery: run `34680856596`.
- Immutable exact-source Release: `desktop-1.2.56-c6183ebc1fbe`.
- Release-chain: run `34680936263`, success; it automatically dispatched the production FCM controller.

## Fresh production controller and target

- Controller: `34680943569`, failure.
- Automatically dispatched target: `34680986090`, attempt `1`, failure.
- Exact device: `gha-34680986090-1-macos-app`.
- Target source: `c6183ebc1fbe93807d8bb1252171a4d5247a9b27`.
- Target tag: `desktop-1.2.56-c6183ebc1fbe`.

The controller log proves the exact assistant projection resolved successfully at generations 77, 195, and 253, including after the two self-hosted channels and after the non-empty global-search clear/close path. The `search` category passed. This closes the original assistant-projection blocker without broadening the exact assistant id.

## Recorder evidence

Target artifact:

- Name: `fabushi-macos-interactive-evidence-34680986090-1`
- Artifact id: `10293629316`
- Size: `172149708` bytes
- Digest: `sha256:c00159c9f1e16833529372cbd233b90367da9105fa66b7f552c747c1362158cc`

Independent artifact inspection of `macos-session.mov`:

- Codec: H.264
- Resolution: 1024x768
- Duration: 74.198333 seconds
- Frames: 62
- File size: 424357 bytes

`recorder-final.json`:

- `mode=frame-avassetwriter`
- `appleM2ScalerParavirtDriver=false`
- `appleParavirtDisplay=true`
- `hostedParavirtDisplay=true`
- `nativeRecorderPlayable=true`
- `playable=true`
- `firstSampleDecoded=true`
- `failClosed=true`

The archive also contains Playwright traces, App/system/device-call logs, release provenance, and 126 screenshots. This closes the originally scoped recorder blocker on the fresh current runner.

## Truthful failure and new blocker

The target report intentionally records:

- `controlStatus=failed`
- `remoteActionCount=29`
- `playwrightOutcome=success`
- `recorderPlayable=true`

The production external journey failed when `messageRowIds()` sent `fabushi.app.find` with `limit=200`. Production MCP rejects this with error `-32602`, code `too_big`, because the schema maximum is 100.

At failure time the fresh journey had passed:

- `startup`
- `login`
- `main`
- `conversations`
- `agent`
- `search`

It had entered `send` but had not passed it. Therefore none of the following acceptance claims are valid yet:

- all 27 categories PASS;
- `READY_FOR_LOGOUT PASS -> ci_session_finish -> fresh snapshot -> exact settings-logout`;
- target success;
- truthful evidence gate success.

The new `limit=200` defect is outside this round's frozen implementation scope. It is preserved as the next atomic blocker instead of being silently repaired or ignored.
