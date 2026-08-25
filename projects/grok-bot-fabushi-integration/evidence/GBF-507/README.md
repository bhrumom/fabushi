# GBF-507 Evidence Index

## Source requirement

- `projects/grok-bot-fabushi-integration/source/grok-bot融合优化.txt`
- `projects/grok-bot-fabushi-integration/source/完整telegram融合进fabushi.txt`
- User continuation on 2026-08-25: complete Grok-style UI/behavior fusion, route Bot work through Mahayana multi-step runtime, persist conversations/runs, and drive the dynamic avatar from real execution state.

## Reference and provenance

- Reference repository: `bhrum/grok-bot-0.18-reconstructed`
- Pinned reference commit: `a9f633e09d49a85829b8236331b9e21f7e612634`
- Reuse decision: clean-room observable behavior / API adaptation only. No production renderer, installer payload, vendor visual asset, trademarked product identity, or unlicensed source is copied into Fabushi.

## Branch and pull request

- Branch: `feat/gbf-mahayana-agent-workbench-v1`
- PR: `#2108` — `feat(gbf): fuse Mahayana multi-step agent workbench into Messenger`

## Implementation commits

| Commit | Evidence |
|---|---|
| `01071e5519ea58940c431f1e658c158f39f4a8ec` | Mahayana command/runtime event bridge and forced Agent mode |
| `4a4c0e42c315dc8fc4e31bb842ec46b6025416c4` | Persistent Agent Workbench reducer, actions, runtime projection and dynamic avatar wiring |
| `cae27b7b4672513ed8ed8d94701e2ac328f1caef` | Workbench timeline/approval/tool/artifact UI |
| `4cf3fdff56402e1e27de5a0888861e22fde2875a` | Fabushi-owned Grok-style conversation material |
| `006a84583e9e75c056070aa07338d0c891c6cc47` | Canonical desktop mount |
| `9b119a853ddf89223de4cb55ad5b5d98aa2d5f97` | Multi-step and restart Playwright journey |
| `1ceca38d8e33c7f30480491bb274f7a4c34dd3fc` | Stable restored-run assertion |

## Acceptance evidence captured so far

Initial code head `9b119a853ddf89223de4cb55ad5b5d98aa2d5f97`:

- Electron desktop quality gate run `32797695610`: **success**.
  - canonical application architecture: success
  - Feature Host bridge contract: success
  - lightweight architecture/UI contracts: success
  - Electron main-process contracts: success
  - Renderer TypeScript: success
- Host fast E2E run `32797695647`: **success**.
- Messaging Product Gate Electron Messenger contract: **success**.
- Final branch head and canonical-main acceptance remain pending because task/project evidence commits changed the head after the initial checks.

## Required final evidence

- [ ] Required PR checks successful on exact final head
- [ ] Protected merge commit
- [ ] Canonical-main `mahayana-agent-workbench.spec.ts`
- [ ] Packaged macOS/Windows/Linux Electron journey where required by release pipeline
- [ ] Screenshot/video/trace artifacts showing planning, multiple steps, final result and avatar state changes
- [ ] Post-main file/behavior verification

## Truthfulness note

This index records implementation and currently observed checks only. It is not a release-completion claim. `GBF-507` remains `IN_PROGRESS` until the final evidence checklist is complete.
