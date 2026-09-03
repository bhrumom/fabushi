# M8-AEO-001 — AEO / AI 应用发现

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-AEO-001`
- **Status**: `COMPLETED / PRODUCTION_VERIFIED`
- **Started**: 2026-08-27
- **Completed**: 2026-08-27
- **Branch**: `feat/tfi-m8-aeo-ai-discovery`
- **Base**: `main@ef985df53a625e4bc2fb685b74724f43f2065302`
- **PR**: #2177 — https://github.com/bhrumom/fabushi/pull/2177
- **Merge SHA**: `a9f7c8e8a98a17fdbd2358232048607198069a0b`
- **Production**: https://fabushi.ombhrum.com/

## Objective

在现有 Host + Marketplace + WebMCP 架构内实现可验证的 AI 应用发现层，使 AI 可通过网页实体、机器 JSON、答案页和 WebMCP 稳定发现、理解、引用并在用户允许时调用 Mini Apps。

## Delivered

- Marketplace catalog remains the single app fact source.
- Every catalog app has a deterministic `/apps/{slug}/#app` entity and SoftwareApplication/WebApplication JSON-LD.
- Production exposes aggregate/per-app/content/answer JSON feeds, `llms.txt`, `llms-full.txt`, and 8 answer intent pages.
- sitemap includes answers and machine endpoints; robots explicitly allows OAI-SearchBot, ChatGPT-User, Googlebot and Bingbot while excluding `/api/`.
- WebMCP exposes read-only `recommend_fabushi_app` and `get_app_capabilities` alongside existing tools.
- Frontend CI includes the AI discovery contract; typecheck, contract and official web build passed.
- PR merged through protected main and the exact merge SHA deployed successfully to the official Cloudflare Worker.

## Acceptance evidence

1. `/ai/apps.json` reports 8 catalog apps; `/ai/answers.json` reports 8 answer intents.
2. `computer-cleaner` resolves to `https://fabushi.ombhrum.com/apps/computer-cleaner/#app`, with `SoftwareApplication` and `WebApplication` types and 4 capabilities.
3. All requested production machine/page routes returned HTTP 200 with the expected content types.
4. sitemap contains the answer route and per-app machine route; the rendered app page contains the same stable entity and SoftwareApplication JSON-LD.
5. OAI-SearchBot, Googlebot and Bingbot User-Agent probes returned HTTP 200. A raw spoofed `ChatGPT-User` request is rejected by edge verification; this does not block the OAI search crawler and robots continues to allow it.
6. Production browser runtime advertised both new WebMCP discovery tools with read-only annotations and their complete input contracts.
7. PR-head CI run `33052057013`, merge-group CI `33052191860`, exact-main CI `33052308165`, official Worker deploy `33052308128`, and Mini Apps Cloudflare deploy `33052308170` succeeded.

## Open-source survey

Reviewed `AnswerDotAI/llms-txt`, `schemaorg/schemaorg`, and `modelcontextprotocol/typescript-sdk`. Public format and contract conventions were adapted; no upstream code was copied and no new dependency was added.

## Residual notes

- `llms.txt` is an auxiliary discovery surface and does not guarantee inclusion in any answer engine.
- The Browser WebMCP bridge advertised the tools but its test invocation did not return before the harness timeout; registration, input contracts, read-only annotations, catalog-derived outputs and production HTTP surfaces are verified. This is recorded as harness/runtime follow-up rather than hidden as a successful invocation.
- Git transport on the current network remains unstable; GitHub connector operations are the authoritative delivery record.
