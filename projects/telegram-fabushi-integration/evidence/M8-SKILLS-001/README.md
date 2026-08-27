# M8-SKILLS-001 evidence

## Scope

Skills over MCP progressive discovery for Fabushi MiniApps.

## Branch evidence

- Branch: `feat/tfi-skills-over-mcp`
- Requirement record: `source/2026-08-27-skills-over-mcp.md`
- ADR: `decisions/ADR-0012-skills-over-mcp-progressive-disclosure.md`
- Task: `management/tasks/M8-SKILLS-001-skills-over-mcp.md`

## Implementation evidence

- Server adapter: `ai-backend/src/miniapp_skills.js`
- MiniApp MCP Resource integration: `ai-backend/src/miniapp_marketplace_server_common.js`
- Host progressive loader: `frontend/packages/mcp-app-sdk/src/skills.ts`
- SDK export: `frontend/packages/mcp-app-sdk/src/index.ts`

## Contract tests

- `ai-backend/test/miniapp_skills.test.js`
- `frontend/packages/mcp-app-sdk/test/skills.test.ts`

## Acceptance state

`TESTING / IN_PROGRESS`.

No CI, protected merge, or canonical-main result is claimed in this record yet. Populate PR/check/merge evidence after current-head GitHub Actions complete. The broader M8 exact-main packaged/release gate remains separate and must not be inferred from this atomic task.
