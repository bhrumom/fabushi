# M8-SKILLS-001 — Skills over MCP progressive discovery

- **Project**: FAB-P0001 / TFI
- **Stage**: M8 Mini Apps
- **Status**: TESTING / IN_PROGRESS
- **Source**: `../../source/2026-08-27-skills-over-mcp.md`
- **Decision**: `../../decisions/ADR-0012-skills-over-mcp-progressive-disclosure.md`

## Deliverable

Fuse Agent Skills into the existing MiniApp MCP model without creating a second execution runtime: server-side Skill discovery/resource publication, progressive resource loading, origin-scoped identity, per-file digest verification, and preserved Tool approval boundaries.

## Acceptance criteria

1. MiniApp Bot MCP publishes at least one Skill when callable commands exist.
2. Skill listing returns metadata/frontmatter and complete per-file `{uri,digest}` entries without eagerly embedding bodies.
3. `skills/get` equivalent single-entry lookup exists during the experimental extension window.
4. The primary Skill is readable through MCP Resources and its bytes match the advertised `sha256:` digest.
5. Host SDK identity is `server origin + Skill URI`, preventing same-name silent shadowing across origins.
6. Host SDK rejects digest mismatch, unlisted supporting files, and static Skills without a resource manifest by default.
7. Loading a Skill does not bypass write/open-world/destructive approval and never auto-executes bundled scripts.
8. Global Dharma receives a concrete safe-operation workflow Skill.
9. Relevant Node/TypeScript contract tests and repository required checks pass.
10. Completion requires protected main merge and canonical-main readback; release/delivery gates remain governed by the broader M8 release task.

## Implementation state

- `ai-backend/src/miniapp_skills.js`: Skill entry/resource generation, `skills_list` / `skills_get` compatibility bridge, SHA-256 file manifest.
- `ai-backend/src/miniapp_marketplace_server_common.js`: MiniApp Bot resource registration now includes Skills.
- `frontend/packages/mcp-app-sdk/src/skills.ts`: lazy Host loader, origin-scoped identity, byte limit, digest validation, supporting-resource allowlist.
- Tests: `ai-backend/test/miniapp_skills.test.js`, `frontend/packages/mcp-app-sdk/test/skills.test.ts`.

## Compatibility note

SEP-2640 remains experimental and had no core-maintainer acceptance vote as of 2026-08-27. Fabushi therefore keeps the native extension boundary replaceable. The current compatibility tools mirror `skills/list` and `skills/get` data semantics while actual Skill content is delivered through standard `resources/read`.

## Blockers / next action

- Open PR and run current-head CI.
- If current MCP SDK exposes a stable native SEP-2640 server handler before merge, replace the compatibility bridge without changing the data model.
- Do not mark COMPLETED until protected merge + canonical-main verification are recorded.
