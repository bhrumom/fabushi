# Fabushi Chrome Web App / Computer Control Bridge Fusion

- Project ID: FAB-P0011
- Project Key: CWA
- Status: active / implementation in progress
- Canonical path: projects/fabushi-chrome-web-app/
- Authoritative repository: bhrumom/fabushi, branch main
- Allocation baseline: canonical main `656d05e8d66bfed241f5b9d871a062abfbf2f952`

## Objective

把独立的 ChatGPT Computer Control Bridge 完整融合到 Fabushi Chrome 扩展，让一个
Fabushi 0.5.0 扩展同时承载产品 UI、桌面账户桥、现有 Chrome 的 Computer Control
和已批准的自动化用户脚本；迁移完成后通过 Chrome UI 删除旧 Bridge 与官方 ChatGPT
扩展。

## Verified state and next gate

The task branch contains the first-class MV3 package, two isolated native bridges,
generation-bound tab claims, the legacy command/event contract tests, and the bundled Task
Queue userscript. The next gate is PR CI plus canonical-main packaged Electron/Chrome E2E;
release and local profile migration remain pending.

## Scope

In scope: product shell parity with Fabushi 0.4.1, all nine Bridge commands,
Debugger/OOPIF/download/tab lifecycle behavior, desktop account reuse, secure Marketplace
userscript controls, native-host migration, explicit packaging, and release evidence.
Out of scope: copying official ChatGPT bookmarks/history/sidebar features or deleting shared
Computer Use runtime/native accessibility helpers.

Start with SOURCE_OF_TRUTH.md, then PROJECT.yaml, docs, management records, ADRs,
evidence and runbooks. The atomic task is management/tasks/CWA-006-computer-control-bridge-fusion.md.
