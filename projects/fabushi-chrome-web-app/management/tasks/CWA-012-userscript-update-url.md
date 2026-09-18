# CWA-012 — 油猴式用户脚本更新 URL

- Portfolio Project: `FAB-P0011`
- Project Key / Task ID: `CWA / CWA-012`
- Status: `IN_PROGRESS / PACKAGED_DELIVERY_PENDING`
- Started/updated: `2026-09-18`; completed: null
- Source: `source/2026-09-18-userscript-update-url.md`
- Branch: `codex/cwa-userscript-update-url-20260918`
- PR / commit / canonical-main SHA: pending

## Objective

让 Marketplace 只承担用户脚本的首次发现和安装；已安装脚本以后通过自身声明的
`@updateURL` / `@downloadURL` 检查脚本元数据中的 `@version`，不再要求每次脚本发布
都修改 Marketplace 的 `latestVersion`、source ref、大小或摘要。旧版固定 commit 清单
仍用于兼容安装和迁移，但不再是用户脚本更新判断的唯一来源。

## Scope and dependencies

范围包括 Chrome MV3 用户脚本元数据解析、后台定时更新检查、旧 catalog 合同到稳定
raw GitHub 更新地址的迁移、自动安装与当前匹配标签页重新激活、Marketplace 状态展示、
纯逻辑合同测试和相关治理记录。

不包括任意远程 JavaScript、`@require`/`@resource`、动态导入、非 HTTPS 更新地址、
绕过 GitHub 仓库边界的更新源，也不包括本地应用构建或浏览器 E2E。

依赖现有 CWA Marketplace 安装合同、ChatGPT 用户脚本源仓库和受保护 `main`/Chrome
打包交付流程。

## Acceptance criteria

1. `@updateURL` 和 `@downloadURL` 被按油猴元数据解析并持久化；脚本自身 `@version`
   是版本判断权威，市场目录的旧版本不能覆盖它。
2. 后台启动、打开 Marketplace、手动检查和 30 分钟 alarm 都会读取更新 URL；旧
   Marketplace 记录可迁移到同仓库稳定 raw 分支地址，不要求每次发布更新目录。
3. 远程版本更高时，下载脚本并通过 HTTPS/raw GitHub、同仓库、脚本身份、大小、
   元数据和现有源码安全校验后替换；启停状态、脚本 ID 和安装时间保持不变，并重新
   激活匹配的 ChatGPT 标签页。
4. 远程检查失败、版本回退、名称/命名空间不一致或校验失败时不替换当前脚本，且
   UI/状态可见失败原因。
5. 旧目录显示 2.9.35、更新 URL 返回 2.9.37 的回归覆盖必须通过；旧版 catalog
   不得把已更新脚本标记为降级/异常。
6. 完成受保护 PR、canonical-main 回读、Chrome 打包/模拟用户 E2E 和发布交付门禁；
   在这些门禁完成前任务保持 `IN_PROGRESS`。

## Verification

- Lightweight local: JavaScript syntax checks、`git diff --check`、userscript metadata/
  Marketplace pure contract tests。
- GitHub Actions: Chrome extension validator/package and required exact-main packaged
  journey with screenshot/video/trace/report evidence; no local application build or E2E。
- Release: only after accepted canonical-main package/E2E evidence; Release must bind to the
  accepted SHA and be strictly update-comparable.

## Open-source-first survey and reuse decision

- [Tampermonkey metadata documentation](https://www.tampermonkey.net/documentation.php?locale=zh_CN):
  `@version` is required for update checks; `@updateURL` supplies the check source and
  `@downloadURL` supplies the download source. Used as the requested behavior reference.
- [Greasemonkey Metadata Block](https://sourceforge.net/p/greasemonkey/wiki/Metadata_Block/):
  documents metadata-only update checks and fallback behavior when `@downloadURL` is omitted.
  Used as the protocol/compatibility reference; no code copied and no runtime dependency added.
- Reuse decision: retain Fabushi's existing `normalizeUserScript`, `userScripts` runner and
  bounded GitHub/raw-host security boundary; replace only the fixed-catalog version decision
  for userscripts with metadata URL discovery and preserve the package updater contract for
  non-userscript artifacts.

## Implementation summary

Implemented in the task worktree: metadata URL parsing, metadata-authoritative versions,
record provenance fields, direct update URL discovery with backward-compatible derivation from
the old pinned raw artifact, remote source size/identity checks, automatic installation and
active-tab reactivation, stale-catalog UI handling, catalog-independent userscript checks, and
ten focused pure tests passing.

## Evidence, blockers and next action

- Local: `node --check` for changed extension modules and focused Marketplace tests `10/10`
  passed; no application build/package/E2E was run locally.
- CI/package/post-main/Release evidence: pending.
- Blocker: this task needs a fresh PR from canonical `main`, protected checks, packaged Chrome
  verification and the required post-main delivery loop before it can be reported complete.
- Next action: review the patch, open the governed PR, run required GitHub Actions checks, then
  validate the installed Chrome profile against the accepted package.
