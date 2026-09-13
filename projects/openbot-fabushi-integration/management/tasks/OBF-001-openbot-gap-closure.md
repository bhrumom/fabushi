# OBF-001 — OpenBot gap closure

Status: `IN_PROGRESS`
Started: 2026-09-13
Source: `Fabushi:173d215e-3b26-4bbd-9609-4110d72f4133`
Baseline: `main@25aaf4fef98fb33ca0100c8cdbd6c7971390ec94`
Pinned upstream: `CopilotKit/OpenBot@19fdcbb7fd5c072d5c2aa95800fcbbbf72aa202c`

Objective: close only verified gaps after mapping OpenBot features to existing Fabushi capabilities; then prove the reference scene in one fresh packaged run.

Verified gaps found in this round:

1. roster CSS overrode canonical identity with position-based `nth-child` silhouettes;
2. parity CSS targeted stale thinking/action class aliases rather than live `agentThinkingRow` / `agentActionRow` runtime surfaces;
3. ordinary assistant completion rendered only plain text and could not project the reference final table/source chips;
4. ordinary assistant message card did not visibly reuse BotMark identity or expose the reference hover actions;
5. the OpenBot static parity contract had fallen out of `build:renderer` / package-script wiring;
6. no dedicated real packaged reference acceptance existed.

Minimal repair in the task branch: remove positional silhouette mutation; style the real event-driven rows; add a generic runtime-authored structured-result renderer (heading/table/source chips) with no hard-coded reference transcript; reuse existing reply/copy/more operations as hover controls; render the same BotMark canonical identity on assistant message cards; rewire the parity contract; add PR-level identity/geometry regression and a production-only packaged Playwright acceptance that requires real Mahayana, real packaged executable and the supplied reference screenshot.

Acceptance remains exactly `docs/19-完成定义与验收.md`. CI/test-mode output can prove contracts but cannot satisfy the post-main packaged gate. Branch/commit/PR/CI/Release/evidence fields remain pending until produced, and status must not be changed to `complete` while any packaged or visual evidence is missing.
