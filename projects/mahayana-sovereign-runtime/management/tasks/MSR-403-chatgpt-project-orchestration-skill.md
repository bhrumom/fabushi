# MSR-403 — ChatGPT project-team orchestration skill

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-403
- **Status:** in-progress
- **Started:** 2026-09-05T12:11:09+08:00
- **Updated:** 2026-09-05T12:11:09+08:00
- **Completed:** null

## Objective

Add a reusable skill to the official `chatgpt-auto-confirm` plugin that turns the
user's architecture → atomic execution → code review → test/release → formal
release workflow into a durable, evidence-gated project-team protocol.

## Source requirements

- User request in the originating conversation: use ChatGPT's Chat surface as
  the planning/review authority, keep one browser tab per project group, wait
  for the stop-answering control to disappear, persist every stage in the
  repository project folder, and promote work only after review and test gates.
- MSR-R02 and MSR-R08: Mahayana-owned extension/skill contracts and
  differentiated workflow/tool demonstrations.
- Existing plugin contracts in
  `.agents/plugins/plugins/chatgpt-auto-confirm/skills/`.

## In scope

- A discoverable `chatgpt-project-orchestration` skill under the official plugin.
- Prompt-independent rules for project selection, durable records, five project
  groups, atomic task fan-out, exact-head review, packaged/E2E evidence, and
  release promotion.
- ChatGPT Chat-mode/model/waiting rules, context rollover in the same tab, and
  security/credential boundaries.
- Plugin contract coverage proving the skill entrypoint and metadata are
  packaged; project records and evidence index updates.

## Out of scope

- Implementing Fabushi product behavior, Mahayana CLI runtime behavior, or a
  browser automation transport.
- Copying code from Grok Build, OpenAI Codex, or the reconstructed Grok Bot.
- Changing the existing hidden ChatGPT controller, credential flow, or release
  workflow semantics.

## Dependencies

- MSR-401 extension/skill contracts.
- The existing `drive-chatgpt-devspace`, `actions-first-task-queue`, and
  `chatgpt-browser-session-driver` controller capabilities.
- Protected GitHub `main` and the plugin runtime validation workflow.

## Acceptance criteria

1. The plugin contains a valid, discoverable skill with `SKILL.md`, metadata,
   and a focused reference protocol.
2. The skill defines architecture, execution, code-review, test/release, and
   formal-release responsibilities, including durable repository records and
   explicit promotion/blocking gates.
3. The skill requires Chat mode, GPT-5.6 Sol with Extra High reasoning when
   available, one browser tab per project group, same-tab fresh conversations
   for atomic isolation/context rollover, and waiting until the stop-answering
   control disappears before reading or sending again.
4. The skill requires exact commit/PR/head and full simulated-user evidence
   review before release, while preserving the repository's no-local-heavy-build
   rule and credential safety boundaries.
5. Lightweight validation passes, the relevant GitHub Actions checks pass, the
   PR is merged into protected `main`, and the canonical `main` readback shows
   the skill and task records.

## Verification

- `skill-creator` quick validation of the new skill folder.
- Focused plugin contract test for the new skill files (run in GitHub Actions;
  no local application build/test).
- GitHub Actions plugin runtime validation for the exact PR head.
- Protected merge, canonical-main readback, and project-record consistency.

## Open-source-first survey and decision

- `xai-org/grok-build` (Apache-2.0 first-party code; reviewed `main`
  `72a61251fcffb464bcc687aeb5a998e5a98ec0c9`) was reviewed as a mature
  local/interactive/headless coding-agent and workspace/tool runtime. Its
  capability separation informs the skill's planner/executor boundaries, but
  no source is copied and its runtime is not made a dependency.
- `openai/codex` (Apache-2.0; reviewed `main`
  `459a79eb85400af759e9220c7bafb4429ae07516`) was reviewed as a local
  coding-agent and CLI
  baseline. Its local execution model informs the distinction between a
  controller and the repository checkout, but the skill remains
  Mahayana/plugin-owned.
- `bhrum/grok-bot-0.18-reconstructed` (reviewed `main`
  `107877b4e2134fd167d239411386f09e42eadd6d`) is an unofficial, low-activity,
  source-oriented reconstruction. It is treated as a behavioral reference for
  bot/session separation only, not as a dependency or copied implementation.
- Existing Fabushi plugin skills and the repository governance skill are the
  compatible patterns reused: concise entrypoint, routed reference protocol,
  durable task files, exact-head evidence, and protected-main closure.

## Branch / commit / PR

- Branch: `codex/chatgpt-project-orchestration-skill`
- Commit: pending
- PR: pending

## Implementation summary

Added the following plugin assets:

- `skills/chatgpt-project-orchestration/SKILL.md` — concise entrypoint and
  hard gates for the five project groups.
- `skills/chatgpt-project-orchestration/references/orchestration-protocol.md` —
  message envelope, durable record fields, parallel execution, exact-head
  review, E2E evidence and video-release handoff protocol.
- `skills/chatgpt-project-orchestration/agents/openai.yaml` — discoverability
  metadata and default prompt.
- `test/contract.test.mjs` — focused packaging/discoverability assertions.
Updated the MSR roadmap, WBS, acceptance matrix, risk/dependency/action/status,
architecture/quality/release/security docs and evidence index.

## CI / E2E / security / performance / release evidence

- Local lightweight: `quick_validate.py` passed; `git diff --check` passed.
- GitHub Actions: pending exact PR head; the plugin runtime workflow remains the
  authoritative package-level validation.

## Post-main delivery classification

Application packaged E2E/release: **N/A for this task**, because the change is
limited to plugin skill instructions, metadata, a reference protocol, a
contract assertion, and project records; it does not change the Fabushi
application runtime or installer. Plugin runtime Actions validation is still
required and will be recorded here.

## Blockers / risks

- The skill must remain an orchestration contract rather than silently assuming
  a particular browser or hidden-app transport.
- User-visible wording must not weaken the existing Chat-mode-only,
  credential-redaction, approval-card, or protected-main rules.

## Next action

Commit the named skill, contract and project-record files, push the focused
branch, open the protected PR, and wait for the exact-head Actions result.
