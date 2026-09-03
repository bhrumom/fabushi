# 01 WBS 原子任务

| Task | Action | Dependency | Acceptance | Verification | Status | Next |
|---|---|---|---|---|---|---|
| FAM-001 | Establish canonical project record | none | full standard folder + portfolio registration | governance validator + PR/main evidence | in-progress | merge baseline |
| FAM-101 | Inventory existing E2E/workflows and map marketable feature scenarios | FAM-001 | scenario registry with stable IDs/owners | source audit | planned | inspect workflows/tests |
| FAM-102 | Define campaign package manifest/schema | FAM-001 | versioned schema covers provenance/media/policy/publish states | schema tests | planned | implement schema |
| FAM-201 | Implement GitHub Actions video/screenshot capture | FAM-101 | one real feature produces valid raw video + checkpoints | CI run artifacts | planned | pilot stable scenario |
| FAM-202 | Add media derivative pipeline | FAM-201 | source -> 9:16/1:1/16:9 + subtitle-ready outputs | media validation CI | planned | implement transform |
| FAM-203 | Add privacy/secret visual/content gate | FAM-201 | unsafe captures blocked before eligibility | adversarial fixtures | planned | implement gate |
| FAM-301 | Generate evidence-grounded content variants | FAM-102,FAM-202 | captions/scripts never exceed evidence state | claim-policy tests | planned | implement transformer |
| FAM-302 | Editorial approval + audit state machine | FAM-203,FAM-301 | review decisions durable/auditable | state-machine tests | planned | implement |
| FAM-401 | Implement platform-neutral publish queue/adapter contract | FAM-302 | idempotent retries and reconciliation | contract tests | planned | implement core |
| FAM-402 | Integrate first supported publishing platform | FAM-401 | controlled real publication/reconciliation | production evidence | planned | choose adapter by supported API |
| FAM-403 | Add additional self-media adapters | FAM-402 | each adapter passes policy/contract/rollback gates | adapter CI + production smoke | planned | platform-by-platform |
| FAM-501 | Daily dev-progress campaign generator | FAM-301 | verified merged changes become eligible daily package | daily workflow dry run | planned | implement |
| FAM-502 | Analytics + attribution ingestion | FAM-402 | post -> campaign -> feature/evidence mapping | reconciliation test | planned | implement |
| FAM-503 | Experiment framework | FAM-502 | title/hook/format experiments measured without fake engagement | experiment audit | planned | implement |
| FAM-601 | Always-on operations and reliability | FAM-403,FAM-501,FAM-502 | sustained cadence + SLO/runbooks | 30-day ops evidence | planned | operate/iterate |
