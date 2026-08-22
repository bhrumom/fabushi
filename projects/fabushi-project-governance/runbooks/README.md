# Governance Runbooks

Use this directory for repeatable repository-governance procedures.

## Standard project intake / recovery

1. Read root/nested `AGENTS.md`.
2. Search `projects/` for a matching objective.
3. Reuse the matching project or create the enterprise scaffold.
4. Read `SOURCE_OF_TRUTH.md`, metadata/owners, relevant specs, WBS/milestones/acceptance/risks/dependencies/status/changelog/issues/actions, ADRs, task record, and evidence.
5. Verify live GitHub branch/PR/CI/release/deployment facts.
6. Open/update a stable task record before substantial work.
7. Execute and verify only eligible work.
8. Update project records/evidence in the same change stream when possible.
9. Merge through protected-main policy.
10. Re-read canonical `main` before marking passed.

## Duplicate project recovery

If two project folders overlap:

1. Stop creating new tasks in both folders.
2. Compare source-of-truth/scope/active tasks.
3. Choose one canonical folder based on the user's objective and existing evidence.
4. Record the consolidation decision in changelog/ADR when material.
5. Move or cross-reference outstanding task/evidence history without rewriting prior facts.
6. Mark the non-canonical folder archived/superseded rather than deleting audit history.

## Governance drift recovery

If root `AGENTS.md`, governance Skill, Task Orchestration standard, or project template drift:

1. Open a governance task under this project.
2. Identify the canonical current standard from user requirement + accepted ADR/spec.
3. Patch all affected control planes in one change stream when possible.
4. Validate Skills independently from GitHub CI.
5. Update WBS/acceptance/status/changelog/evidence.
6. Verify merged `main` and document any external Skill installation action still required.

Last validated: 2026-08-22 (FPG-002 implementation branch; canonical validation pending merge).
