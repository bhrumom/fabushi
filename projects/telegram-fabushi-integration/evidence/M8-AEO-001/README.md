# M8-AEO-001 evidence index

- Project: `FAB-P0001 / TFI`
- Task: `M8-AEO-001`
- Status: `COMPLETED / PRODUCTION_VERIFIED`
- Product PR: [#2177](https://github.com/bhrumom/fabushi/pull/2177)
- Merge SHA: [`a9f7c8e8a98a17fdbd2358232048607198069a0b`](https://github.com/bhrumom/fabushi/commit/a9f7c8e8a98a17fdbd2358232048607198069a0b)
- Production: https://fabushi.ombhrum.com/

## Delivery gates

| Gate | Evidence | Result |
|---|---|---|
| Source contract/typecheck/build | PR-head CI [33052057013](https://github.com/bhrumom/fabushi/actions/runs/33052057013) | SUCCESS |
| Protected merge | merge-group CI [33052191860](https://github.com/bhrumom/fabushi/actions/runs/33052191860), PR #2177 merged | SUCCESS |
| Canonical readback | main latest commit and `ai-discovery.ts` / route fetched at merge SHA | SUCCESS |
| Exact-main CI | [33052308165](https://github.com/bhrumom/fabushi/actions/runs/33052308165) | SUCCESS |
| Official Worker deploy | [33052308128](https://github.com/bhrumom/fabushi/actions/runs/33052308128) | SUCCESS |
| Mini Apps Cloudflare deploy | [33052308170](https://github.com/bhrumom/fabushi/actions/runs/33052308170) | SUCCESS |
| Production HTTP | 10 requested routes returned 200 with JSON/text/HTML/XML content types | SUCCESS |
| Entity/JSON-LD | 8 apps; stable computer-cleaner `#app`; dual SoftwareApplication/WebApplication types; rendered entity match | SUCCESS |
| Answers/sitemap | 8 answers; answer and machine app URLs present in sitemap | SUCCESS |
| WebMCP runtime | production browser advertised both new read-only tools and schemas | SUCCESS (registration) |
| Crawler reachability | OAI-SearchBot, Googlebot, Bingbot probes returned 200 | SUCCESS |

## Production route sample

- `/ai/apps.json`
- `/ai/apps/computer-cleaner.json`
- `/ai/content.json`
- `/ai/answers.json`
- `/llms.txt`
- `/llms-full.txt`
- `/answers/clean-computer-storage-safely/`
- `/apps/computer-cleaner/`
- `/sitemap.xml`
- `/robots.txt`

## Runtime caveat

The in-app Browser discovered and published `recommend_fabushi_app` and `get_app_capabilities` with `readOnlyHint: true`, but the bridge invocation did not return before the harness timeout. A raw spoofed `ChatGPT-User` request was rejected by edge verification while the actual indexing crawler identity requested by this task, `OAI-SearchBot`, returned 200. These observations are retained explicitly; no invocation or crawler result is fabricated.
