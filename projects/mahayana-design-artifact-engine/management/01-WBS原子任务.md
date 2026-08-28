# WBS 原子任务

| Task | Action | Acceptance | Verification | Status | Next |
|---|---|---|---|---|---|
| MDA-001 | project/provenance bootstrap | registered FAB-P0009 + pinned upstream | portfolio/project audit | in-progress | protected-main merge + canonical readback |
| MDA-101 | design package contract + Fabushi package | manifest/DESIGN/tokens consistent | Node contract + MDA CI | in-progress | final PR CI + post-main delivery |
| MDA-201 | design skill metadata + craft registry | portable SKILL.md plus Fabushi extensions | trusted context contract + desktop gate | in-progress | final PR CI + post-main delivery |
| MDA-301 | isolated skill/resource staging | no source mutation/traversal/symlink escape | filesystem/security tests | in-progress | final PR CI + post-main delivery |
| MDA-401 | declarative runtime profile layer | Mahayana remains loop owner | adapter/runtime-convergence checks | in-progress | final PR CI + post-main delivery |
| MDA-501 | typed artifact manifest + safe preview | workbench routes typed artifacts safely | preview security + desktop tests | in-progress | packaged desktop E2E after merge |
| MDA-601 | export capability registry + executors | fail-closed formats + real HTML/source/PDF output | exporter contract tests | in-progress | packaged desktop E2E after merge |
| MDA-701 | MiniApp design/publish handoff | generated MiniApp uses existing runtime/marketplace | handoff contract + MiniApp E2E | in-progress | packaged MiniApp journey after merge |

## Current branch evidence

- PR: #2198
- Head after preload syntax correction: `104312d102b09853aaa973b4bd00903c35dd61e5`
- Isolated macOS worktree verification: `node --check` for preload/context plus 8 Node contract tests, all passed.
- Completion remains gated on protected-main merge, canonical-main readback, required packaged E2E evidence, and Release publication for the accepted main SHA.
