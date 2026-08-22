# Fabushi Enterprise GitHub Project Folder Standard

## 1. Canonical location and identity

All durable Fabushi project folders live under:

`projects/<project-slug>/`

Use lowercase kebab-case. A project folder represents one coherent objective/workstream, not a chat session, branch, or individual PR.

Reuse an existing project when the request is a continuation, fix, migration, release, verification round, or refinement of the same objective. Create a new project only when scope, success criteria, and lifecycle are materially independent.

## 2. Mandatory standard scaffold

Create this scaffold for every new project:

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

Do not leave required files blank. If a standard document is genuinely not applicable, keep the file and state `N/A`, the reason, the owner for revisiting it, and the condition that would make it applicable.

## 3. Required metadata

`PROJECT.yaml` must include at least:

```yaml
project_id: <stable-id>
name: <human-readable name>
slug: <project-slug>
status: active
repository: bhrumom/fabushi
authoritative_branch: main
authoritative_path: projects/<project-slug>
owner: <person/team/agent responsibility>
reviewers: []
current_stage: <stage-id-or-name>
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
```

Recommended optional fields:

```yaml
risk_tier: tier-0|tier-1|tier-2|tier-3
security_classification: public|internal|confidential|restricted
target_finish: YYYY-MM-DD|null
related_projects: []
source_systems: []
```

Never store credentials, tokens, signing material, or other secrets.

## 4. Root files

### README.md

Provide an onboarding-quality entry point containing objective, current verified status, current stage and next gate, scope/non-goals summary, source-of-truth pointer, owners/reviewers, primary acceptance definition, and navigation to specs, management, ADRs, evidence, and runbooks.

A new engineer or agent must be able to understand the project without reading the originating chat.

### SOURCE_OF_TRUTH.md

State:

- authoritative repository, branch, and project path;
- original source/requirement files or external references;
- precedence among latest persisted user requirements, source files, specs, ADRs, management state, GitHub/CI facts, external mirrors, and chat memory;
- implementation-fact rule: code/PR/CI/release/deployment state must be verified from live systems;
- conflict-resolution rule so corrections are recorded rather than silently rewriting history.

### OWNERS.md

Define accountable owner, execution owner, required reviewers, consulted stakeholders, and escalation path. Use a lightweight RACI-style table when multiple teams are involved.

## 5. Source intake

`source/` preserves original requirements and durable pointers.

Include original user/task requirements, linked email/file/issue/PR identifiers when applicable, external references needed to interpret scope, and dated requirement changes.

Do not silently rewrite original source material. Put interpretation and normalized requirements in `docs/`.

## 6. Product and engineering documents

### `00-项目章程.md`

State problem, objective, users/stakeholders, business value, constraints, assumptions, high-level deliverables, success definition, and governance model.

### `01-范围与非目标.md`

Maintain explicit in-scope and out-of-scope boundaries. Separate deferred items from rejected/non-goal items.

### `02-需求与成功指标.md`

Use stable requirement IDs. Define functional/non-functional requirements and measurable success metrics. Link critical requirements to acceptance criteria.

### `03-架构与实现策略.md`

Describe current state, target state, components, interfaces, data/control flow, deployment topology, compatibility/migration strategy, performance constraints, and major design tradeoffs. Link durable decisions to ADRs.

### `04-质量与测试策略.md`

Define unit/contract/integration/E2E/security/performance tests as applicable, test data strategy, environments, required CI checks, flaky-test handling, and evidence retention.

### `05-发布迁移与回滚.md`

Define rollout strategy, migration sequence, feature flags/canary when used, rollback triggers/steps, data rollback limits, release ownership, and post-release validation.

### `06-运维可观测性与SLO.md`

For runtime/user-facing systems, define SLI/SLO targets, logging/metrics/tracing, dashboards, alerts, runbook links, capacity assumptions, and incident signals. For non-runtime projects, mark N/A with reason.

### `07-安全隐私与合规.md`

Record data classes, authentication/authorization boundaries, threat considerations, secrets handling, privacy/compliance requirements, dependency/supply-chain risks, and required security review. Never store secrets.

### `19-完成定义与验收.md`

Define project-level Definition of Done. Every required criterion needs an objective verification method and evidence type. Distinguish implementation complete, release complete, migration complete, and project complete where they differ.

## 7. Management documents

### `00-路线图.md`

Use a stage-based roadmap with entry/exit gates and explicit ordering/dependencies.

### `01-WBS原子任务.md`

Use stable task IDs. Every required task includes action, dependency, acceptance criterion, verification method, evidence requirement, status, blocker, and next action. Avoid subjective completion percentages.

### `02-里程碑.md`

Track milestone ID, target, required tasks/gates, planned date, actual date, status, and evidence.

### `03-验收追踪矩阵.md`

Trace:

`Requirement -> Task/implementation -> Verification -> Evidence -> Status`

Mark `passed` only when objective evidence exists.

### `04-风险登记.md`

Use a RAID-style register: risk ID, description, probability, impact, severity, owner, mitigation, trigger, contingency, status, and review date.

### `05-状态报告.md`

Append-only round history. Record timestamp, task/stage, completed work, acceptance result, evidence, blocker/risk, next action, and verified progress change.

### `06-依赖与阻塞.md`

Track internal/external dependencies, required version/date/owner, blocking relation, fallback, and state.

### `07-变更日志.md`

Append scope, requirement, design, governance, migration, or implementation-record changes. Never erase prior entries to make history cleaner.

### `08-问题与行动项.md`

Track open question/action ID, owner, due date, decision deadline, resolution, and linked ADR/task when closed.

### `management/tasks/`

Create one durable record for each substantial atomic task:

`<task-id>-<short-slug>.md`

Minimum fields:

- stable Task ID;
- objective;
- source requirement IDs/references;
- in scope / out of scope;
- dependencies;
- acceptance criteria;
- verification/checks;
- branch/commit/PR;
- status;
- implementation summary;
- evidence;
- blockers/risks;
- next action;
- started/updated/completed timestamps.

## 8. ADRs

Use `decisions/ADR-XXXX-<slug>.md` for decisions expensive to reverse or that materially constrain architecture, protocol, data model, security, deployment, CI/CD, governance, or vendor choice.

Each ADR should include status, date/decision owners, context, decision, alternatives, consequences/tradeoffs, rollout/migration implications when relevant, and superseding/superseded links.

Do not use ADRs for routine implementation details.

## 9. Evidence

Use `evidence/<task-id>/README.md` as an index for non-trivial evidence.

Prefer durable references to commit SHA, PR/review, Actions run/job/check, test/security/performance reports, release/artifact, and deployment/environment checks.

Do not commit credentials, tokens, private customer data, signing material, or large build binaries as project evidence.

## 10. Runbooks

Use `runbooks/` for deploy, rollback, recovery, migration, incident response, data repair, key rotation, or other repeatable operational procedures. Link each runbook to its owning component/task and last validation date.

## 11. AGENTS.md, Skills, CI/CD, docs governance are not exempt

Repository meta/governance changes must follow the same project standard as product code.

The following require an existing matching project folder or a newly created one **before substantial work**:

- root or nested `AGENTS.md` changes;
- Skill creation, update, removal, packaging, or installation work;
- CI/CD/workflow/merge-policy changes;
- branch protection and release governance;
- architecture standards and repository-wide policies;
- documentation-system migrations;
- build/release tooling changes;
- security/governance automation.

If a matching governance project already exists, reuse it. Otherwise create a separate governance project with its own source, scope, WBS, acceptance criteria, evidence, and completion gate.

## 12. Completion gate

Before declaring a repository task complete:

1. Execute the defined acceptance check.
2. Update the task record with actual result/evidence.
3. Update WBS.
4. Update acceptance traceability.
5. Append status report.
6. Append material changelog.
7. Update risks/dependencies/issues/roadmap/ADRs/specs when affected.
8. Record commit/PR/CI/release/deployment evidence.
9. Merge through the repository's required protected-main process.
10. Verify canonical state on `main`.

If any required gate is pending, keep the task `in-progress`, `blocked`, or `failed`.

## 13. Quality audit checklist

A project folder passes audit only when:

- a new engineer/agent can reconstruct objective, scope, current state, and next action without chat history;
- every required task has stable identity and objective acceptance;
- requirements trace to implementation and evidence;
- completed claims are supported by live/verifiable evidence;
- risks and dependencies have owners;
- durable architecture/governance choices have ADRs;
- status/change history is append-only;
- release/migration/rollback and SLO/runbook material exists where operational risk requires it;
- secrets/private data are absent;
- project and external control views use the same stable IDs.
