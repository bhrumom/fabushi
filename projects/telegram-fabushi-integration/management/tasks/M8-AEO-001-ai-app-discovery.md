# M8-AEO-001 — AEO / AI 应用发现

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-AEO-001`
- **Status**: `IN_PROGRESS`
- **Started**: 2026-08-27
- **Updated**: 2026-08-27
- **Branch**: `feat/tfi-m8-aeo-ai-discovery`
- **Base**: `main@ef985df53a625e4bc2fb685b74724f43f2065302`
- **PR / merge / release**: pending

## Objective

在现有 Host + Marketplace + WebMCP 架构内实现可验证的 AI 应用发现层，使 AI 可通过网页实体、机器 JSON、答案页和 WebMCP 稳定发现、理解、引用并在用户允许时调用 Mini Apps。

## Source

- `source/2026-08-27-aeo-ai-app-discovery.md`
- 用户当前会话明确要求的 9 项交付范围。

## In scope

- stable app entity IDs and complete SoftwareApplication/WebApplication JSON-LD;
- `/ai/apps.json`, per-app JSON, content and answer feeds;
- `llms.txt` and `llms-full.txt`;
- answer intent pages + sitemap;
- WebMCP recommendation/capability discovery;
- explicit crawler allow rules;
- CI contract/build, production deploy and HTTP/runtime evidence;
- TFI WBS/acceptance/status/changelog/evidence synchronization.

## Out of scope

- replacing the shared Host shell or Marketplace;
- a second catalog/database;
- weakening write/install/runtime approval;
- claiming guaranteed inclusion in any AI answer engine.

## Dependencies

- canonical Marketplace catalog: `frontend/apps/web/src/lib/marketplace.ts`;
- existing global WebMCP mount and `@fabushi/mcp-app-sdk`;
- current Next.js static export and Cloudflare deployment workflows.

## Acceptance criteria

1. Every catalog app has one deterministic `#app` entity and a machine-readable per-app endpoint.
2. Aggregate app/content/answer feeds return schema/version, stable absolute URLs and catalog-derived data.
3. Every answer slug statically renders, includes direct answer + recommended app, and appears in sitemap.
4. `llms.txt` remains concise; `llms-full.txt` exposes full catalog-derived capabilities, permissions and content links.
5. WebMCP exposes `recommend_fabushi_app` and `get_app_capabilities` as read-only tools.
6. robots explicitly allows requested crawlers while retaining API exclusions.
7. AI-discovery contract test, frontend typecheck/build and relevant CI are green.
8. PR merges through protected main; canonical main is re-read.
9. production endpoints, JSON schemas, robots and WebMCP runtime registration are HTTP/runtime verified.

## Verification plan

- GitHub Actions frontend typecheck/build and AI-discovery source contract.
- Inspect generated/static routes from CI/deploy.
- After merge/deploy: HTTP 200/content-type/schema checks for all machine endpoints, one answer page, app JSON-LD and robots.
- Runtime browser/WebMCP registration check for the two discovery tools.
- Application-affecting completion remains subject to repository post-main delivery/evidence rules.

## Open-source survey

Reviewed `AnswerDotAI/llms-txt`, `schemaorg/schemaorg`, and `modelcontextprotocol/typescript-sdk`. Adapt public formats and contract ideas only; no upstream code copied and no new dependency added.

## Risks / blockers

- Cloudflare WAF may still block allowed bots independently of robots; production user-agent probes are required.
- llms.txt adoption is auxiliary and cannot guarantee model inclusion.
- Git transport on the current network is unstable; GitHub connector is the authoritative branch/file/PR path for this task.

## Next action

Implement the catalog-derived discovery layer and CI contract, then open the PR and drive all delivery gates.
