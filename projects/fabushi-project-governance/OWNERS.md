# Owners and Review Responsibility

## Accountability

| Role | Owner | Responsibility |
|---|---|---|
| Accountable owner | Repository maintainers | Approve repository-wide governance policy and protected-main behavior |
| Execution owner | Active task agent/engineer | Implement the governed task and keep project records current |
| Required reviewers | Repository maintainers for sensitive governance/CI/security changes | Review changes that alter enforcement, delivery, security, or repository-wide policy |
| Consulted stakeholders | Project owners affected by a governance change | Validate compatibility with project-specific needs |
| Informed stakeholders | Contributors/agents working in `bhrumom/fabushi` | Follow current `main` governance rules |

## Escalation

Escalate when:

- two project folders claim authority over the same objective;
- a requested change conflicts with root `AGENTS.md`, protected-main policy, or accepted ADRs;
- a task would weaken required CI, merge, release, security, or evidence gates;
- a project cannot meet the enterprise standard without a justified N/A or migration plan.

Escalation target: repository maintainers and the accountable owner of the affected project.

## Review rule

Changes to root `AGENTS.md`, repository Skills, CI/CD, merge policy, security/governance automation, or the enterprise project-folder standard are governance-sensitive and require objective validation plus the repository's protected merge process.
