# 2026-09-18 — User-directed test and release authority

## Original requirement

The user explicitly supersedes the prior rule that formal/stable publication must be preceded by Fabushi official MCP testing.

Current requirement:

- Remove the mandatory requirement to use the Fabushi official MCP for release testing.
- Run behavioral/product testing only when the user explicitly asks to test.
- If the user explicitly says the current candidate may be published / asks to publish, proceed with publication without inventing an additional MCP, E2E, smoke, regression, simulator, emulator, or other behavioral-test gate.
- For test/release sequencing, the latest explicit user instruction is the controlling requirement.

## Normative interpretation

1. **No default behavioral-test gate.** Repository agents and release automation must not require Fabushi official MCP, E2E, smoke, regression, simulator/emulator, or equivalent behavioral validation merely because a candidate is a formal/stable release.
2. **Testing is opt-in by explicit user request.** Behavioral/product tests are run only when the user explicitly requests testing for the current task/candidate. Do not infer a test requirement from historical project records, prior release policy, an older task, or agent preference.
3. **User release authorization is sufficient for the behavioral gate.** When the user explicitly instructs `发布`, `可以发布`, or an equivalent publication authorization for the current candidate, do not block publication on an unrequested MCP/E2E test.
4. **Latest explicit user instruction wins on test/release sequencing.** If an older repository document says MCP/E2E testing is mandatory, this dated requirement supersedes that conflict.
5. **Non-behavioral integrity and platform constraints remain distinct.** Source identity, version monotonicity where required by a store/channel, signing/notarization, artifact integrity/provenance, protected-branch rules, credentials/permissions, and store/platform acceptance requirements are not behavioral tests and are not removed by this requirement. They should be satisfied with the minimum necessary release-construction work.
6. **Do not silently substitute another test.** If MCP testing is not requested, do not replace it with autonomous E2E or another behavioral suite. If the user requests a specific test, run that requested scope unless the user expands it.
7. **No retroactive testing requirement.** Existing candidates/tasks that were blocked only because mandatory MCP behavioral validation had not run are no longer blocked for that reason. Their release eligibility should be reevaluated against the latest explicit user instruction plus non-behavioral release constraints.

## Scope

This requirement governs repository-wide CI/CD, release/promotion, project acceptance language, Agent instructions, and future task planning wherever they conflict on whether behavioral testing is mandatory before publication.

It does not authorize bypassing repository/platform permissions or falsifying release evidence. Publication must still truthfully report what was and was not tested.
