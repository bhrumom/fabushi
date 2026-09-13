# OBF-001 — OpenBot gap closure

Status: `IN_PROGRESS`
Started: 2026-09-13
Source: `Fabushi:82655b0d-e929-44c7-a4f4-fdcfd0a13c8a`
Initial round baseline: `main@9365b5e13f1fb5ac7b31f00049e487ab2174edbc`
Synchronized canonical base: `main@c41e9305dd2c2af4f48139dadfefe71eef50068f`
Pinned upstream: `CopilotKit/OpenBot@19fdcbb7fd5c072d5c2aa95800fcbbbf72aa202c`
Active PR: `#2584` (`feat/obf-openbot-gap-closure-20260913`)

Objective: close only verified gaps after mapping OpenBot features to existing Fabushi capabilities; never create a second OpenBot executor/control plane; then prove the exact reference scene in one fresh production packaged run.

Verified product gaps found in the branch:

1. roster CSS overrode canonical identity with position-based `nth-child` silhouettes;
2. parity CSS targeted stale thinking/action class aliases rather than live `agentThinkingRow` / `agentActionRow` runtime surfaces;
3. ordinary assistant completion rendered only plain text and could not generically project the reference final table/source chips;
4. ordinary assistant message card did not visibly reuse BotMark identity or expose the existing reply/copy/more operations as reference-style hover actions;
5. the OpenBot static parity contract had fallen out of `build:renderer` / package-script wiring;
6. no dedicated real packaged reference acceptance existed.

Minimal product repair remains presentation/projection only: remove positional silhouette mutation; style the real Mahayana event-driven rows; add a generic runtime-authored structured-result renderer (heading/table/source chips) with no hard-coded reference transcript; reuse existing reply/copy/more operations as hover controls; render the same BotMark canonical identity on assistant message cards; rewire the parity contract. Existing Fabushi computer/browser/files/tools/live-screen/take-over/policy/audit implementations are reused as documented in `docs/08-OpenBot能力映射.md`; no second executor, container supervisor, browser tenancy service, MCP gateway, audit store, transcript store, or remote-control protocol is added.

This gap-closure round additionally hardened the acceptance contract instead of adding product runtime:

- while work was running, canonical main advanced from `9365b5e...` to `c41e9305...`; PR #2584 was synchronized so its merge-base is the latter before further validation;
- production packaged acceptance refuses inherited test/mock/stub FeatureHost mode and `FABUSHI_E2E=1`, removes host-test overrides from the child process, verifies the exact reference crop hash, and requires an exact source SHA;
- the same run must write reference and Fabushi screenshots, full video, Playwright trace, runtime logs, Mahayana lifecycle/workbench state, exact app/source manifest, identity continuity, layout geometry, and global/per-region visual-diff metrics;
- visual audit regions cover navigation/roster widths, all four roster avatars, message/transcript, final result card/table, source/attachment cards, hover operations, and composer; any non-zero residual is quantified and cannot be called 1:1;
- restart proof remains production-only: the same Chief identity must keep the same `data-shape` in roster/header/final transcript and after relaunch with the same packaged app-data directory.

Current verification state:

- implementation + PR/test-host contracts exist on PR #2584;
- fresh production packaged evidence is still `PENDING` in this round; no current same-run video/trace/log/visual-diff bundle has been produced and accepted yet;
- PR CI is not treated as the packaged evidence gate, and a skipped `OBF_REAL_ACCEPTANCE` test is never a pass;
- the currently available graphical Fabushi Desktop devices are offline, so a Linux source/test-host run is not accepted as a substitute for the requested packaged Desktop evidence.

Acceptance remains `docs/19-完成定义与验收.md` plus `docs/09-视觉回归规范.md`. Status must remain `IN_PROGRESS` until protected merge/exact-main packaged execution produces the required same-run evidence, real `thinking -> running/completed/failed -> assistant completion` proof, stable Bot identity after restart, and an accepted quantified visual result. Literal `1:1` is allowed only for zero measured visual difference.