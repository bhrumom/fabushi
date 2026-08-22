# Agent Instructions

This repository contains the Fabushi app and website. Follow the user's request first, then these repository instructions.

## CRITICAL: Project-First Task Governance — Every Task Must Use `projects/`

These rules are mandatory for **every task** performed in this repository, including implementation, bug fixes, refactors, reviews, investigations, releases, documentation changes, CI/CD work, migrations, and follow-up rounds.

### 1. Start every task by locating its project folder

Before substantial work:

1. Inspect the current GitHub `main` branch under `projects/`.
2. Decide whether the request belongs to an existing project or is a genuinely different objective/workstream.
3. If a matching project exists, **reuse it**. Do not create a duplicate folder merely because the chat/session is new.
4. Read the matching project's `SOURCE_OF_TRUTH.md` first, then `README.md`, `PROJECT.yaml`, relevant `source/`, `docs/`, `decisions/`, and `management/` files.
5. Read the current WBS, acceptance matrix, status report, changelog, risks, and active task record before deciding what to implement next.
6. Verify code, branch, PR, CI, release, and deployment facts against GitHub rather than assuming documentation is current.

### 2. If no project folder exists, create one before implementation

If the request does not belong to an existing project, create a new lowercase kebab-case folder under:

`projects/<project-slug>/`

At minimum create and populate:

```text
projects/<project-slug>/
├── README.md
├── PROJECT.yaml
├── SOURCE_OF_TRUTH.md
├── source/
│   └── README.md
├── docs/
│   ├── 00-项目章程.md
│   ├── 01-范围与非目标.md
│   └── 19-完成定义与验收.md
├── management/
│   ├── 00-路线图.md
│   ├── 01-WBS原子任务.md
│   ├── 03-验收追踪矩阵.md
│   ├── 04-风险登记.md
│   ├── 05-状态报告.md
│   ├── 07-变更日志.md
│   └── tasks/
├── decisions/
│   └── README.md
└── evidence/
    └── README.md
```

Do this **before substantial implementation** so the task has a durable scope, acceptance definition, and execution record from the beginning.

### 3. Every substantial task must have a durable task record

Create or update:

`projects/<project-slug>/management/tasks/<task-id>-<short-slug>.md`

The task record must include at least:

- stable Task ID;
- objective and source requirement;
- in-scope / out-of-scope;
- dependencies;
- acceptance criteria;
- verification method;
- branch / commit / PR;
- status;
- implementation summary;
- CI / E2E / release / deployment evidence when applicable;
- blockers and risks;
- next action;
- started, updated, and completed timestamps.

### 4. Drive implementation from the project folder

The GitHub project folder is the durable working context. Use it to decide what comes next rather than relying on chat memory.

- Reconstruct the current state from the project folder at the start of each task/round.
- Advance the existing roadmap/WBS instead of inventing a parallel plan in chat.
- Record newly discovered requirements in `source/` or the appropriate spec.
- Record scope/design changes in `management/07-变更日志.md`.
- Record long-lived architecture decisions under `decisions/` as ADRs.
- Keep planned work and completed work clearly separated.
- Prefer the same branch/PR for implementation and its project-record updates.

### 5. Task completion is blocked until the project folder is updated

Do **not** report a task as complete merely because code was written, pushed, or a test passed.

Before saying a task is finished:

1. Run or inspect the defined acceptance checks.
2. Update the task record with actual results and evidence.
3. Update `management/01-WBS原子任务.md` for affected task states.
4. Update `management/03-验收追踪矩阵.md` when acceptance status changed.
5. Append the round/result to `management/05-状态报告.md`.
6. Append material changes to `management/07-变更日志.md`.
7. Update risks, roadmap, specs, and ADRs when affected.
8. Record commit SHA, PR number, CI run/job, release/deployment evidence, blockers, and next action where applicable.
9. Commit the project-record changes to GitHub in the same task change stream when possible.
10. Verify the canonical result on GitHub `main` after merge. If CI/merge/release is still pending, keep the task `in-progress`, `blocked`, or `failed`; do not mark it complete.

### 6. Source-of-truth precedence

Unless a project defines a stricter rule, use this precedence:

1. the user's latest explicit requirement **after it is persisted into the GitHub project folder**;
2. `projects/<project-slug>/SOURCE_OF_TRUTH.md` and the source files it designates;
3. accepted ADRs and current project specs;
4. current WBS/status/acceptance records;
5. GitHub code/PR/CI/release/deployment facts for implementation state;
6. external mirrors such as Google Drive;
7. conversation memory.

Google Drive, chat history, email, local notes, and other external copies are intake/reference material unless the project explicitly promotes them. They must not silently override the GitHub `main` project folder.

### 7. Required governance skill

For project/task lifecycle details, follow:

`.agent/skills/fabushi-project-governance/SKILL.md`

and its references:

- `.agent/skills/fabushi-project-governance/references/project-folder-standard.md`
- `.agent/skills/fabushi-project-governance/references/task-lifecycle.md`

The root `AGENTS.md` rule is repository-wide. More specific nested instructions may add requirements, but must not bypass the requirement to locate/create a project folder and keep its task records current.

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
