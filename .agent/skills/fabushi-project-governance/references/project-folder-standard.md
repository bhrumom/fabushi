# Fabushi GitHub project folder standard

## Canonical location

All durable project folders live under:

`projects/<project-slug>/`

Use lowercase kebab-case slugs. A project folder represents one coherent objective/workstream, not one chat session.

## Minimum scaffold for a new project

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

Add specialist docs only when the project needs them. Do not create empty ceremony for its own sake.

## Required metadata

`PROJECT.yaml` should include at least:

```yaml
project_id: <stable-id>
name: <human-readable name>
slug: <project-slug>
status: active
repository: bhrumom/fabushi
authoritative_branch: main
authoritative_path: projects/<project-slug>
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
```

## SOURCE_OF_TRUTH.md

State:

- the authoritative repository, branch, and folder;
- which source files carry original requirements;
- precedence among source, specs, ADRs, management records, and external mirrors;
- rule that GitHub code/CI/release evidence determines implementation facts;
- rule that external Drive copies are mirrors/reference only unless explicitly promoted.

## README.md

Include:

- objective;
- current status;
- key scope;
- canonical source links/paths;
- current stage;
- primary acceptance definition;
- navigation to docs, management, decisions, evidence.

## Management files

### `01-WBS原子任务.md`
Use stable task IDs. Every required task has an acceptance criterion and objective verification method.

### `03-验收追踪矩阵.md`
Map requirements -> implementation/evidence -> status. Mark passed only when evidence exists.

### `05-状态报告.md`
Append round-by-round factual progress. Include date/time, task ID, completed work, tests, evidence, blockers, next action.

### `07-变更日志.md`
Append scope/design/implementation-record changes. Do not erase previous entries.

### `management/tasks/`
Create one durable execution record per task/round when substantial work begins. File naming:

`<task-id>-<short-slug>.md`

Minimum fields:

- Task ID
- Objective
- Source requirement
- In scope / out of scope
- Dependencies
- Acceptance criteria
- Verification commands/checks
- Branch / PR
- Status
- Implementation summary
- Evidence
- Blockers/risks
- Next action
- Started/updated/completed timestamps

## Evidence

Use `evidence/<task-id>/README.md` as an index when evidence is non-trivial. Prefer durable GitHub links to:

- commits;
- PRs;
- Actions runs/jobs;
- test reports;
- releases/artifacts;
- deployment checks.

Do not commit credentials, tokens, signing secrets, private user data, or large binary artifacts as evidence.
