# ADR-0007 — User-directed behavioral testing and publication

- Status: Accepted
- Date: 2026-09-18
- Project: FAB-P0003 / FCM
- Source: `source/2026-09-18-user-directed-test-and-release-authority.md`

## Context

The previous repository policy made Fabushi official MCP validation a mandatory prerequisite for formal/stable publication. The user explicitly revoked that requirement and directed that behavioral testing occur only when the user asks for testing. The user also directed that an explicit publication instruction/authorization should allow publication without an additional self-imposed behavioral-test gate.

## Decision

1. Behavioral/product testing is opt-in by explicit user request.
2. Fabushi official MCP is not a default release gate. It is used when the user explicitly asks for MCP-based testing.
3. An explicit user instruction to publish / statement that a candidate may be published is sufficient to clear the behavioral-test gate for that candidate.
4. Automatic E2E and other behavioral suites remain disabled by default and must not be silently substituted for MCP.
5. Non-behavioral release-construction/platform constraints remain in force: source identity, required version progression, build/sign/package/notarization, artifact integrity/provenance, protected-branch permissions, credentials/security, and store/channel acceptance.
6. Release evidence must truthfully state whether behavioral testing was requested and performed.

## Consequences

- Missing MCP connectivity or App-owned devices no longer blocks publication when MCP testing was not requested.
- Historical tasks whose only blocker is the superseded mandatory MCP gate must be reevaluated under the latest user instruction.
- Future agents must not add a new behavioral gate unless the user explicitly requests that testing.
- If the user requests tests, the requested scope remains evidence-bearing; if the user does not request tests, no behavioral pass should be implied.
