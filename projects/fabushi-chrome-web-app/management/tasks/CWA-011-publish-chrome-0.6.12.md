# CWA-011 — Publish Fabushi Chrome 0.6.12

- Portfolio Project: `FAB-P0011`
- Project Key: `CWA`
- Task ID: `CWA-011`
- Started/updated: `2026-09-18`
- Status: `in-progress`
- Source: `source/2026-09-18-chrome-0.6.12-publish.md`

## Objective

Publish a monotonically newer Fabushi Chrome extension that bundles the already-released ChatGPT auto-confirm userscript `v2.9.37`, then submit the exact canonical-main package to the Chrome Web Store.

## Acceptance criteria

1. Extension `manifest.json` is `0.6.12` and release packaging/publish workflows accept exactly `0.6.12`.
2. Bundled `userscript/chatgpt-auto-confirm.user.js` is byte-identical to source release `v2.9.37` at `c6cf4e3fce76c0e62ad2be4d409044d5b2486d0f`, size `239555`, SHA-256 `64af1493153cccc4c172b1d1092379e77ca8f662c30ab42e3ed5a610b5e391f5`.
3. Marketplace fallback/install metadata advertises `2.9.37` and pins the exact commit, digest, size and release URL.
4. Change lands through the repository's protected-main flow and canonical main is re-read.
5. The zero-test Chrome packaging workflow succeeds for the exact canonical-main SHA and retains the package/checksum/content-manifest artifact.
6. The Chrome Web Store publish workflow runs with `dry_run=false` against that exact package. A Web Store state of `PENDING_REVIEW`, `STAGED` or `PUBLISHED` proves the requested publication action was submitted; only `PUBLISHED` may be described as publicly live.
7. No MCP/E2E/smoke/regression/product-behavior testing is run because the user did not request testing.

## Evidence to record

- branch / PR / exact head / merge SHA;
- zero-test package Action run and package artifact checksum;
- Chrome Web Store publish Action run and redacted status/provenance artifact;
- final Web Store state returned by the API;
- explicit statement that behavioral testing was not requested/run.
