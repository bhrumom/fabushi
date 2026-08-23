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
4. **Before declaring that task complete or ending it as finished**, actively drive its PR through all required review/CI/protected-main/merge-queue gates and merge it into canonical `main`. If it cannot yet merge, keep that task `in-progress`, `blocked`, or `failed` rather than calling it complete.
5. Re-read/verify the relevant files and engineering facts from canonical GitHub `main` after merge. A PR being open, approved, green, queued, or merely pushed is not enough for task completion.
6. Only after merge plus canonical-main verification may that individual task be marked `passed` / `completed` and reported as finished.

**Parallelism is explicitly allowed:** multiple independent tasks and PRs may be active at the same time, including while another PR is waiting on CI or the merge queue.

**Closure is still strict:** every active task owns its own PR-to-main closure gate. Before finishing a task, the agent must return to that task, push its PR toward merge, resolve merge blockers when possible, and verify the result on `main`. Pending PRs must remain visible in project/task records until closed.

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
- branch / commit / PR;
- status;
- implementation summary;
- CI / E2E / security / performance / release / deployment / migration evidence when applicable;
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
- Parallel independent task/PR work is permitted. Keep each task separately tracked, and do not mark any task complete until that task's own PR satisfies the §1B merge-and-main-verification closure gate.

### 6. Task completion is blocked until project records and evidence are current

Do **not** report a task as complete merely because code was written, pushed, or a test passed.

Before saying a task is finished:

1. Run or inspect the defined acceptance checks, including `Project portfolio governance` when project identity/registry metadata is affected.
2. Update the task record with actual results and evidence.
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
13. Do not mark or report that task as finished until steps 11–12 are complete. Other independent tasks may proceed in parallel while these gates are pending.

If any required review/CI/merge/release/deployment/migration/acceptance gate is pending, keep that task `in-progress`, `blocked`, or `failed` rather than marking it complete. This pending state does **not** prohibit work on other independently tracked tasks/PRs.

### 7. Source-of-truth precedence

Unless a project defines a stricter rule, use this precedence:

1. the user's latest explicit requirement **after it is persisted into the GitHub project folder**;
2. for portfolio identity/allocation, canonical `projects/PORTFOLIO.json` and `projects/PROJECT_ID_POLICY.md` on GitHub `main`;
3. `projects/<project-slug>/SOURCE_OF_TRUTH.md` and designated source files;
4. accepted ADRs and current project specs;
5. current WBS/milestone/status/acceptance records;
6. GitHub code/PR/CI/release/deployment facts for implementation state;
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

The root `AGENTS.md` rule is repository-wide. More specific nested instructions may add requirements, but must not bypass portfolio Project ID allocation, project-folder creation/reuse, task records, acceptance evidence, the PR-to-main completion gate, or completion closure.

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