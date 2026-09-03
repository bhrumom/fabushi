# Agent Instructions

This repository contains the Fabushi app and website. Follow the user's request first, then these repository instructions.

## CRITICAL: Project-First Task Governance — Every Task Must Use `projects/`

These rules are mandatory for **every task** performed in this repository, including product implementation, bug fixes, refactors, reviews, investigations, releases, migrations, documentation changes, CI/CD work, repository governance, `AGENTS.md` changes, Skill creation/update, architecture standards, branch/merge policy, and follow-up rounds.

There are **no meta-work exemptions**. Work that changes this `AGENTS.md`, `.agent/skills/**`, `.github/**`, project standards, build/release tooling, security/governance automation, or other repository-control files must itself belong to a governed project folder.

### 1. Start every task by locating its project folder

Before substantial work:

1. Inspect current GitHub `main` under `projects/` and read canonical `projects/PORTFOLIO.json`.
2. Decide whether the request belongs to an existing project or is a genuinely independent objective/workstream.
3. If a matching project exists, **reuse it and its registered `FAB-Pxxxx` Project ID**. Do not create a duplicate because the chat, branch, PR, or agent session is new.
4. Resolve the project's `project_id`, `project_key`, slug, and authoritative path from the registry and `PROJECT.yaml`.
5. Read the matching project's `SOURCE_OF_TRUTH.md` first, then `README.md`, `PROJECT.yaml`, `OWNERS.md`, relevant `source/`, `docs/`, `decisions/`, `management/`, `evidence/`, and `runbooks/` files.
6. Read current roadmap, WBS, milestones, acceptance matrix, risk register, dependency/blocker register, status report, changelog, open issues/actions, active task record, and relevant ADRs before deciding what to implement next.
7. Verify code, branch, PR, CI, release, deployment, and migration facts against live GitHub/engineering systems rather than assuming project documentation is current.
8. Complete the open-source-first startup gate in §1C before choosing a custom implementation.

### 1A. Global Project ID allocation gate

Fabushi has one immutable portfolio identity namespace for projects:

- `project_id`: global cross-project identity in the form `FAB-P0001`, `FAB-P0002`, ... . It is immutable and never reused.
- `project_key`: stable mnemonic namespace such as `TFI`, `FPG`, `FCM`, `GBF`, or `MSR`; use this for human-readable requirement/task IDs. It is not the portfolio Project ID.
- `legacy_project_ids`: historical aliases preserved for traceability; never reassign an alias to another project.
- `projects/PORTFOLIO.json`: authoritative machine-readable registry and allocation high-water mark.
- `projects/PROJECT_ID_POLICY.md`: authoritative lifecycle/allocation policy.

If no matching project exists and the work is genuinely independent:

1. Re-read `projects/PORTFOLIO.json` from canonical GitHub `main` immediately before allocation. Never allocate from chat memory or a stale branch.
2. Allocate **exactly** the registry's current `next_sequence` using `FAB-P%04d`.
3. In the same branch/PR, append the new registry entry, increment `next_sequence`, and create `projects/<project-slug>/PROJECT.yaml` with the identical `project_id`, a unique stable `project_key`, slug, and authoritative path.
4. Never edit, swap, compact, recycle, or reassign an allocated Project ID. Rename, archive, cancellation, split, merge, or supersession changes project status/history, not its historical identity.
5. If concurrent project creation causes a `PORTFOLIO.json` merge conflict, re-read canonical `main` and reallocate the later project from the new high-water mark. Do not force, duplicate, or reuse the losing sequence.
6. Project/registry changes must pass the `Project portfolio governance` GitHub Actions validator before completion.

### 1B. CRITICAL: PR-to-main completion gate — parallel work allowed, merge required before task closure

Fabushi repository work **may proceed in parallel across independent tasks and PRs**. Waiting for CI, review, branch protection, or a merge queue on one task must not prevent productive work on another independent task. The hard gate applies to **task completion**, not to task start.

For every repository task that uses a PR:

1. Finish that task's implementation, project records, and objective acceptance checks on its own branch/PR.
2. Open and manage the task PR. While that PR is waiting on required review, CI, branch protection, or merge queue state, the agent may create, switch to, implement, and advance other independent tasks/PRs in parallel.
3. Keep tracking the pending PR and return to it to resolve failures, conflicts, or requested changes. Parallel work is not permission to abandon a pending PR or lose its durable task/evidence state.
4. **Before declaring that task complete or ending it as finished**, actively drive its PR through all required review/CI/protected-main/merge-queue gates and merge it into canonical `main`. If it cannot yet merge, keep the task `in-progress`, `blocked`, or `failed` rather than calling it complete.
5. Re-read/verify the relevant files and engineering facts from canonical GitHub `main` after merge. A PR being open, approved, green, queued, or merely pushed is not enough for task completion.
6. Apply the delivery rule in §1D only when the task acceptance requires a test/formal release, deployment, store delivery, or task-specific E2E. Merge-to-main plus the task-defined acceptance evidence is sufficient for ordinary application changes.

**Parallelism is explicitly allowed:** multiple independent tasks and PRs may be active at the same time, including while another PR is waiting on CI, the merge queue, an explicitly requested platform release, or formal-release E2E.

**Closure is still strict:** every active task owns its own PR-to-main evidence and any delivery evidence explicitly required by that task. Pending requested releases/E2E must remain visible in project/task records until closed.

### 1C. CRITICAL: Open-source-first task startup gate

Before implementing a task, redesigning an existing component, or inventing a new protocol/framework/tool, **search mature open-source repositories first** for a proven implementation of the same or closely related problem.

For every substantive task:

1. Search relevant upstream/official and well-maintained open-source repositories before substantial implementation. Prefer the canonical project and primary source repository over blogs, snippets, forks, or copied code.
2. Inspect the candidate's architecture, APIs/data model, test strategy, operational edge cases, security posture, maintenance activity, license, and compatibility with Fabushi's current Electron/native/Rust architecture.
3. Record the candidate repositories and the decision in the task/project records: what is reused, adapted, rejected, or learned; include the reason and license/provenance implications.
4. If a mature compatible solution exists, **learn it first and reuse/adapt/fuse the proven design**, then optimize and innovate for Fabushi. Do not rebuild the same infrastructure from scratch merely to make it “ours”.
5. Do not blindly copy code. Preserve licensing/attribution obligations, reject incompatible licenses or unsafe/unmaintained approaches, and integrate through Fabushi's own domain boundaries and tests.
6. If no suitable mature implementation exists, record the search scope/candidates and the reason a custom implementation is necessary before writing that custom implementation.
7. Research evidence is part of the task's durable source/decision record and acceptance evidence. Conversation memory alone is not sufficient evidence that a search happened.

This gate is about avoiding duplicated engineering and learning from proven systems; it does not require adopting an open-source dependency when doing so would worsen security, maintainability, performance, licensing, or architectural fit.

### 1D. CRITICAL: Test vs formal delivery — long App E2E is explicit formal-release work only

**Latest explicit policy (2026-09-03): do not run long application-driving E2E automatically on PRs, ordinary `main` pushes, test releases, or generic release attempts.** This policy supersedes the earlier every-main packaged-E2E interpretation.

Use two release lanes:

1. **Test release (default for product iteration):** manually dispatch exactly one platform release workflow. Build/package only that selected platform, reuse safe caches, skip long Playwright/device/simulator/App-driving E2E, and publish a clearly marked test artifact/prerelease. A test release must never silently become stable/latest production.
2. **Formal release:** manually dispatch exactly one platform's formal release workflow. Formal delivery must run the platform's calibrated application E2E plus required signing/notarization/store/source-provenance gates before public stable publication. If the calibrated formal E2E gate is unavailable or known inaccurate, formal release must fail closed until the gate is repaired; do not substitute the test lane.
3. **Per-platform isolation:** macOS, Windows, Linux, Android, and iOS each own a separate manual release workflow. Selecting one platform must not allocate runners/builds for another platform. Legacy combined five-platform release/fan-out workflows remain disabled.
4. **Automatic CI:** keep fast deterministic source/static/unit/type/build-contract checks needed for protected `main`, but do not launch long packaged application journeys automatically. Heavy E2E remains available as manual diagnostics and as a formal-release gate after calibration.
5. **Evidence:** for test releases record source SHA, workflow run, package/prerelease asset, and target-device launch/review evidence when requested. For formal releases additionally retain the required E2E screenshots/video/trace/report/log bundle and platform trust/store evidence.
6. **Task completion:** ordinary product tasks do not need an automatic post-main packaged E2E/Release just to close. They require their defined PR/merge/acceptance evidence. A task whose acceptance explicitly includes a test release, formal release, deployment, store delivery, or task-specific E2E remains open until that named delivery evidence exists.
7. **Recalibration rule:** when a user reports that application-driving E2E is inaccurate, remove it from automatic blocking paths first, produce a current test build, then recalibrate the formal gate against the actual application behavior before re-enabling it.
8. **Updater proof:** previous-installed-App update discovery/install/relaunch remains optional unless a task explicitly requires it.

Build/test work may execute in parallel, but release publication is platform-scoped and explicit. Never restore an umbrella workflow that automatically dispatches every platform or every long E2E without a newer explicit user requirement.

### 1E. CRITICAL: Fast-feedback / warm-build gate — hot-reload-like CI across runs

GitHub-hosted runners are ephemeral, so CI cannot literally keep one process alive between runs. Fabushi must achieve **hot-reload-like feedback** by restoring the previous run's valid build state and rebuilding only the invalidated subgraph.

For build/test workflows:

- Do not intentionally start from zero on every round when a safe reusable cache/artifact exists.
- Use content-addressed/versioned cache keys that include the relevant lockfile, toolchain/SDK version, platform/architecture, build profile, and source inputs. Use bounded `restore-keys` fallbacks only where stale-state correctness is understood.
- Reuse immutable native Host binaries/JNI/static libraries when their source hash is unchanged; reuse npm/pnpm stores, Gradle dependency/build caches, Android AVD snapshots, Xcode DerivedData/SwiftPM state, Rust target/dependency state, and same-run artifacts instead of rebuilding identical inputs.
- Use compiler-result caching such as `sccache` for Rust/C/C++ hot paths when it is compatible with the job, in addition to higher-level artifact caches; keep a normal compiler fallback.
- Build the renderer/native host/package once per compatible input set and hand it to downstream test/package jobs rather than recompiling the same artifact repeatedly.
- Select the smallest safe affected test/build surface for pull requests. After merge, run the required canonical delivery surface, but still reuse caches and unchanged platform intermediates.
- Record cache hit/miss, restored key, compiler-cache statistics where available, and cold/warm wall-clock durations in Actions summaries/evidence. Optimize from measured bottlenecks rather than assumptions.
- A cache miss, eviction, key-version change, or suspected corruption must fall back to a reproducible correct build. Never weaken signing, notarization, required E2E, source provenance, or release integrity to gain speed.
- Cached outputs are acceleration data, not Release provenance. The accepted Release remains identified by the exact `main` source SHA, toolchain/configuration, required test evidence, and signed package artifacts.

### 2. If no project folder exists, create the enterprise standard before implementation

If the request does not belong to an existing project, first allocate the portfolio Project ID under the gate above, then create a lowercase kebab-case folder under:

`projects/<project-slug>/`

Create and populate this standard scaffold **before substantial implementation**:

```text
projects/<project-slug>/
├── README.md
├── PROJECT.yaml
├── SOURCE_OF_TRUTH.md
├── OWNERS.md
├── source/
│   └── README.md
├── docs/
│   ├── 00-项目章程.md
│   ├── 01-范围与非目标.md
│   ├── 02-需求与成功指标.md
│   ├── 03-架构与实现策略.md
│   ├── 04-质量与测试策略.md
│   ├── 05-发布迁移与回滚.md
│   ├── 06-运维可观测性与SLO.md
│   ├── 07-安全隐私与合规.md
│   └── 19-完成定义与验收.md
├── management/
│   ├── 00-路线图.md
│   ├── 01-WBS原子任务.md
│   ├── 02-里程碑.md
│   ├── 03-验收追踪矩阵.md
│   ├── 04-风险登记.md
│   ├── 05-状态报告.md
│   ├── 06-依赖与阻塞.md
│   ├── 07-变更日志.md
│   ├── 08-问题与行动项.md
│   └── tasks/
├── decisions/
│   └── README.md
├── evidence/
│   └── README.md
└── runbooks/
    └── README.md
```

Do not create blank ceremony. If a mandatory standard document is genuinely not applicable, keep the file and state `N/A`, why it is not applicable, who owns revisiting it, and what condition would make it applicable.

### 3. Enterprise project-document requirements

Every project must be reconstructable by a new engineer/agent without the originating chat.

At minimum:

- `README.md`: immutable Project ID/Project Key, objective, current verified status, current stage/next gate, scope summary, owners, source-of-truth pointer, acceptance summary, navigation.
- `PROJECT.yaml`: registered `project_id: FAB-Pxxxx`, stable `project_key`, `legacy_project_ids`, slug, status, repository, authoritative branch/path, owner/reviewers, current stage, timestamps; optional risk/security classification. These identity fields must match `projects/PORTFOLIO.json`.
- `SOURCE_OF_TRUTH.md`: authoritative source precedence and conflict-resolution rules.
- `OWNERS.md`: accountable/execution owners, reviewers, consulted stakeholders, escalation path.
- `source/`: original requirements and durable source references; do not silently rewrite source history.
- `docs/00-项目章程.md`: problem, objective, stakeholders, value, constraints, deliverables, success definition.
- `docs/01-范围与非目标.md`: explicit in-scope, out-of-scope, deferred items.
- `docs/02-需求与成功指标.md`: stable requirement IDs, functional/non-functional requirements, measurable success metrics.
- `docs/03-架构与实现策略.md`: current/target state, components, interfaces, data/control flow, deployment/migration strategy, tradeoffs.
- `docs/04-质量与测试策略.md`: unit/contract/integration/E2E/security/performance strategy as applicable, environments, required CI/evidence.
- `docs/05-发布迁移与回滚.md`: rollout, migration, canary/flags when used, rollback triggers/steps, release validation.
- `docs/06-运维可观测性与SLO.md`: SLI/SLO, logs/metrics/traces, alerts, capacity, runbook links for runtime systems; otherwise N/A with reason.
- `docs/07-安全隐私与合规.md`: data classification, auth boundaries, threats, secrets handling, privacy/compliance, supply-chain/security review.
- `docs/19-完成定义与验收.md`: objective project Definition of Done with evidence type for every required gate.
- `management/`: roadmap, WBS, milestones, acceptance traceability, RAID/risk, append-only status, dependencies/blockers, append-only changelog, open issues/actions, per-task records.
- `decisions/`: ADRs for expensive-to-reverse architecture/protocol/data/security/deployment/CI/CD/governance/vendor decisions.
- `evidence/`: durable evidence indexes for commits, PRs, reviews, CI checks, releases, deployments, migrations.
- `runbooks/`: deploy/rollback/recovery/migration/incident/data-repair/key-rotation or other repeatable operational procedures when applicable.

### 4. Every substantial task must have a durable task record

Create or update:

`projects/<project-slug>/management/tasks/<task-id>-<short-slug>.md`

The task record must include at least:

- immutable portfolio Project ID and Project Key;
- stable Task ID;
- objective and source requirement IDs/references;
- in-scope / out-of-scope;
- dependencies;
- acceptance criteria;
- verification method/checks;
- open-source survey and reuse/rejection decision;
- branch / commit / PR;
- status;
- implementation summary;
- CI / E2E / security / performance / release / deployment / migration evidence when applicable;
- requested test/formal release, deployment, store, or task-specific E2E evidence when applicable; formal E2E includes screenshots/videos/traces/reports/logs; optional updater journey evidence when run or explicitly required;
- blockers and risks;
- next action;
- started, updated, and completed timestamps.

### 5. Drive implementation from the project folder

The GitHub portfolio registry and project folder are the durable working context. Use them to decide what comes next rather than relying on chat memory.

- Reconstruct current state from `projects/PORTFOLIO.json` and the project folder at the start of each task/round.
- Advance the existing roadmap/WBS instead of inventing a parallel plan in chat.
- Record newly discovered requirements in `source/` and/or normalized specs.
- Record scope/design/governance changes in `management/07-变更日志.md`.
- Record durable architecture/governance decisions as ADRs.
- Update risk, dependency/blocker, issue/action, release/rollback, security, SLO, and runbook records when affected.
- Keep planned work and verified completed work clearly separated.
- Prefer the same branch/PR for implementation and its project-record updates.
- Never mutate an existing registered Project ID to make a registry conflict disappear.
- Parallel independent task/PR work is permitted. Keep each task separately tracked, and do not mark any task complete until that task's own PR plus any explicitly required delivery work satisfy §§1B–1E.

### 6. Task completion is blocked until project records, post-main verification, and evidence are current

Do **not** report a task as complete merely because code was written, pushed, a PR was merged, or a source-level check passed.

Before saying a task is finished:

1. Run or inspect the defined acceptance checks, including `Project portfolio governance` when project identity/registry metadata is affected.
2. Update the task record with actual results and evidence, including the open-source-first research decision.
3. Update `management/01-WBS原子任务.md` for affected task states.
4. Update `management/02-里程碑.md` when milestone gates change.
5. Update `management/03-验收追踪矩阵.md` when acceptance status changes.
6. Append the round/result to `management/05-状态报告.md`.
7. Append material changes to `management/07-变更日志.md`.
8. Update risks, dependencies/blockers, issues/actions, roadmap, specs, ADRs, security docs, release/rollback docs, SLOs, and runbooks when affected.
9. Record commit SHA, PR/review, CI run/job/check, test, release, deployment, migration, blockers, and next action where applicable.
10. Commit project-record changes to GitHub in the same task change stream when possible.
11. Merge through required protected-main checks/merge queue.
12. Verify canonical state on GitHub `main` after merge, including registry/project metadata parity when applicable.
13. If the task explicitly requires a test release, verify the selected platform artifact/prerelease is bound to the intended source SHA and record the requested target-device launch/review evidence. Do not run unrelated platforms.
14. If the task explicitly requires a formal release, run the calibrated platform E2E and retain its required visual/debug evidence. A missing, inaccurate, or failing formal E2E gate blocks formal publication; fix/recalibrate it rather than bypassing it.
15. Verify any required GitHub Release/store/deployment evidence is bound to the accepted source SHA and contains the platform's required installable/update assets. Previous-installed-App updater proof remains optional unless explicitly required.
16. Only then mark or report that task as `passed` / `completed`. Ordinary application changes that do not require release/deployment/E2E may close after protected merge, canonical readback, and their own acceptance checks.

If any required review/CI/merge/requested-release/formal-E2E/evidence/deployment/migration/acceptance gate is pending, keep that task `in-progress`, `blocked`, or `failed`. This does **not** prohibit work on other independently tracked tasks/PRs.

### 7. Source-of-truth precedence

Unless a project defines a stricter rule, use this precedence:

1. the user's latest explicit requirement **after it is persisted into the GitHub project folder**;
2. for portfolio identity/allocation, canonical `projects/PORTFOLIO.json` and `projects/PROJECT_ID_POLICY.md` on GitHub `main`;
3. `projects/<project-slug>/SOURCE_OF_TRUTH.md` and designated source files;
4. accepted ADRs and current project specs;
5. current WBS/milestone/status/acceptance records;
6. GitHub code/PR/CI/post-main E2E/release/deployment facts for implementation state;
7. external mirrors/control views such as Google Drive/Sheets;
8. conversation memory.

External systems are intake, scheduling, reporting, portfolio, or mirror systems unless explicitly promoted. They must not silently override the GitHub `main` portfolio registry/project folder for Fabushi engineering work.

### 8. Required governance skill and Task Orchestration alignment

For lifecycle details, follow:

`.agent/skills/fabushi-project-governance/SKILL.md`

and:

- `.agent/skills/fabushi-project-governance/references/project-folder-standard.md`
- `.agent/skills/fabushi-project-governance/references/task-lifecycle.md`

When Task Orchestration is used, preserve the same immutable `FAB-Pxxxx` Project ID, Project Key, Stage ID, Task ID, requirement IDs, acceptance criteria, and evidence links in external control views. Google Sheets is a portfolio/control-plane view; for Fabushi repository work the GitHub portfolio registry/project folder and live GitHub/CI facts remain authoritative.

The root `AGENTS.md` rule is repository-wide. More specific nested instructions may add requirements, but must not bypass portfolio Project ID allocation, project-folder creation/reuse, task records, open-source-first research, acceptance evidence, the PR-to-main completion gate, the explicit test/formal release separation, formal-release E2E evidence when applicable, the optional-by-default updater-proof policy, warm-build integrity, or completion closure.

## CRITICAL: Local Disk Safety — Never Build or Test the App Locally

The development machine used for this repository has insufficient free storage for application builds and test runs. Build outputs, Rust/Electron/Android/iOS caches, test artifacts, downloaded SDK components, browser bundles, and dependency caches can exhaust the disk.

These rules are mandatory for every AI agent working in this repository:

- **Do not build the application locally.** Do not run commands such as `cargo build`, `cargo test`, `npm run build`, `pnpm build`, `gradlew`, `xcodebuild`, or other commands that compile/package the application or generate large build trees.
- **Do not run application, integration, E2E, native, emulator, simulator, or full-suite tests locally.** If a test can compile native code, download large runtime dependencies, launch device tooling, or create large artifacts, treat it as forbidden locally.
- **Do not install large SDKs/toolchains or regenerate native platforms locally just for verification.** This includes Android/iOS/Electron build preparation that materially increases disk usage.
- **Do not delete existing build artifacts, caches, user files, or unrelated directories to make room for a build.** The safe response to low disk space is to move verification to CI, not to clean the user's machine without an explicit request.
- **Use GitHub Actions for builds and tests.** Push/PR validation or a manually dispatched workflow is the source of truth for heavy verification.
- **Prefer the narrowest existing workflow that matches the change.** The main `.github/workflows/ci.yml` is dispatchable and already covers Rust runtime tests, React/Next builds, Worker/E2E contract checks, frontend checks, and other repository CI. Native/mobile/installer validation has dedicated dispatchable workflows including `.github/workflows/native-mobile.yml`, `.github/workflows/electron-desktop.yml`, `.github/workflows/macos-desktop-e2e.yml`, `.github/workflows/native-electron-release.yml`, `.github/workflows/apple-store-delivery.yml`, and `.github/workflows/google-play-delivery.yml`.
- If no existing workflow validates a required heavy operation, **add or extend a GitHub Actions workflow instead of running that operation locally**.
- Local verification is limited to lightweight, non-building checks that have negligible disk impact, such as reading files, reviewing diffs, searching source text, inspecting configuration, checking formatting by inspection, or running a narrowly scoped script only when it is known not to compile/package/download large dependencies.
- If uncertain whether a command is disk-heavy, **do not run it locally**. Use GitHub Actions or report that CI verification is required.

When reporting completion, distinguish clearly between lightweight local inspection and GitHub Actions verification. Never claim a build or test passed unless the corresponding GitHub Actions run actually passed.

## Faliu Anki Card Workflow

Use these instructions whenever you are asked to create, batch-generate, review, or edit memorization cards for the official website 法流 page.

The card data entry point is:

`frontend/apps/web/src/data/faliu-anki-cards.ts`

The 法流 page mounts the card review UI through:

`frontend/apps/web/src/components/faliu-anki-enhancer.tsx`

Do not change the review component just to add more scripture cards. For normal card production, only edit `frontend/apps/web/src/data/faliu-anki-cards.ts`.

## Card Data Shape

Add one `FaliuAnkiDeck` per CBETA work and juan. The `contentId` must match the website's CBETA content id format:

```ts
{
  contentId: "cbeta:T0251:1",
  work: "T0251",
  juan: "1",
  title: "般若波羅蜜多心經",
  cards: [
    {
      id: "cbeta:T0251:1:001",
      front: "請背誦：觀自在菩薩，行深般若波羅蜜多時，照見……",
      back: "五蘊皆空，度一切苦厄。",
      hint: "接在「照見」之後。",
      sourceText: "觀自在菩薩，行深般若波羅蜜多時，照見五蘊皆空，度一切苦厄。",
      tags: ["T0251", "心經", "般若"]
    }
  ]
}
```

Required card fields are `id`, `front`, and `back`. Optional but strongly preferred fields are `hint`, `sourceText`, and `tags`.

Every `id` must be stable and unique. Use this pattern unless the user gives another convention:

`cbeta:<work>:<juan>:<three-digit-number>`

For example: `cbeta:T0235:1:001`, `cbeta:T0235:1:002`.

## How To Make Good Scripture Cards

Make cards for memorization, not commentary. The `back` should usually be the exact text the user is expected to recall. The `front` should give enough cue to recall the answer without giving the answer away.

Prefer these card types:

- Continuation cards: give the beginning of a sentence or verse and ask for the next phrase.
- Cloze-style cards: omit a key phrase from a famous sentence.
- Section cards: ask for the next line in a repeated structure, especially gatha, mantra, vows, lists, or parallel prose.
- Term cards only when the scripture itself contains a compact definitional sentence.

Avoid these card types:

- Long paragraphs that are too large to memorize in one card.
- Opinion, explanation, or doctrinal interpretation in the answer.
- Duplicate cards that test the same phrase in almost the same way.
- Cards whose answer requires information outside the scripture text.

Keep each card focused. A good default answer length is one phrase to one sentence. Split long passages into multiple cards.

## Text Fidelity Rules

Preserve scripture wording exactly in `back` and `sourceText`. Do not silently modernize, simplify, paraphrase, or translate the scripture text unless the user explicitly asks for that.

Use the text style already returned by CBETA for the work. If the source is Traditional Chinese, keep Traditional Chinese. If the source includes Sanskrit transliteration, mantra text, punctuation, or variant characters, preserve them as much as practical.

Remove obvious UI noise, CBETA copyright boilerplate, line-number labels, and footnote anchors from cards. Keep meaningful scripture punctuation when it helps memorization.

## Batch Generation Process

When generating cards for a work or juan:

1. Identify the CBETA `work`, `juan`, and exact `contentId` used by the 法流 page.
2. Read the scripture text for that juan from the existing 法流/CBETA source or from user-provided material.
3. Segment the text into memorization-sized units.
4. Create cards with stable ids, exact answers, helpful hints, and source text for audit.
5. Add or update the matching deck in `frontend/apps/web/src/data/faliu-anki-cards.ts`.
6. Keep existing cards unless the user asks to replace them or they are clearly wrong.
7. Do not run local typecheck/build/test commands when they may compile, bundle, install, or generate substantial artifacts. Use the appropriate GitHub Actions workflow for verification instead.

## Deck Size Guidance

For short texts such as 《心經》 or 《佛說阿彌陀經》, create a complete deck for the whole juan.

For long juans, create a practical first batch unless the user asks for full coverage. A reasonable first batch is 20 to 60 high-value cards, prioritizing famous, repetitive, devotional, or structurally clear passages.

If a scripture contains chapter titles, vows, lists, or repeated formulas, use tags such as `品名`, `偈頌`, `咒`, `願`, `名相`, or the title/topic that helps future filtering.

## Code Style

This is a TypeScript/Next.js frontend. Keep card data as typed TypeScript data. Do not introduce a database, runtime API, or external dependency for normal card additions.

When editing `faliu-anki-cards.ts`, keep formatting simple and readable. Prefer one deck object per work/juan, and keep cards ordered in scripture order.

## Review Checklist

Before finishing a card-generation task, check:

- Each deck `contentId` matches `cbeta:<work>:<juan>`.
- Each card id is unique.
- `back` text is exact scripture text, not a paraphrase.
- `front` does not reveal the answer completely.
- Long passages are split into smaller cards.
- Existing unrelated cards and code are not removed.
- TypeScript syntax is valid.
