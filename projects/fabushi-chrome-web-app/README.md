# Fabushi Chrome Web App / Computer Control Bridge Fusion

- Project ID: FAB-P0011
- Project Key: CWA
- Status: active / existing extension delivered; Grok Bot 0.18 Chrome parity expansion in specification
- Canonical path: projects/fabushi-chrome-web-app/
- Authoritative repository: bhrumom/fabushi, branch main
- Allocation baseline: canonical main `656d05e8d66bfed241f5b9d871a062abfbf2f952`

## Objective

把 Fabushi Chrome 扩展升级为 **Grok Bot 0.18 的 Chrome 插件版**：主应用实现
Grok 的 Agent 工作区、对话/流式/工具/MCP/恢复等功能与 UI，同时完整保留现有
Computer Control、CDP/OOPIF/下载、Mini Apps、Marketplace、油猴脚本、Fabushi
独立登录、同账号 MCP 和 Native Messaging 能力。现有插件能力是批准的扩展能力，
不得因 Grok parity 被删除或降级。

## Verified state and next gate

The task branch contains the first-class MV3 package, two isolated native bridges,
generation-bound tab claims, the legacy command/event contract tests, the bundled Task
Queue userscript, and the explicit userscript `tab-recovery` capability/watchdog. Lightweight
static/security/contract checks, protected merge, canonical-main packaged delivery and the
exact GitHub Release are green. The Chrome Web Store draft is submitted and currently pending
external review; live recovery evidence and public listing/install proof remain pending.

CWA-007 adds independent Fabushi account login and account-scoped official MCP
browser registration in the 0.6.0 change stream. PR, CI, canonical package/E2E,
gateway deployment, Web Store release and production same-account proof remain required.

## Scope

In scope: full Grok Bot 0.18 Chrome-extension product/UI parity; per-source-file audit and
per-product-responsibility implementation; full-page Grok-shaped extension app; durable
Coordinator/Host/Runner lifecycle; all nine Bridge commands/eight actions; Debugger/OOPIF/
download/tab lifecycle; Mini Apps/Marketplace; userscripts; browser login/same-account MCP;
optional desktop/local enhancement; remote Coordinator fallback; packaging and release evidence.
Out of scope: one-to-one file copying, copying proprietary Grok binary assets, weakening
Chrome security boundaries, or deleting existing approved CWA capabilities.

Start with SOURCE_OF_TRUTH.md, then
`docs/08-grok-bot-0.18-extension-architecture-product-parity.md`, PROJECT.yaml, other
docs, management records, ADRs, evidence and runbooks. Existing delivery tasks remain active;
CWA-013 owns the Grok Bot 0.18 extension parity expansion.
