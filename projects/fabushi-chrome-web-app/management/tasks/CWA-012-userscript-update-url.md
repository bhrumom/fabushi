# CWA-012 — 油猴式用户脚本更新 URL

- Portfolio Project: `FAB-P0011`
- Project Key / Task ID: `CWA / CWA-012`
- Status: `IN_PROGRESS / WEB_STORE_REVIEW_AND_PACKAGED_E2E_PENDING`
- Started/updated: `2026-09-18` / `2026-09-19`; completed: null
- Source: `source/2026-09-18-userscript-update-url.md`; follow-up `source/2026-09-19-userscript-marketplace-version-display.md`
- Branch: `codex/cwa-version-display-20260919`
- Host PR / commit / canonical-main SHA: implementation PR #2713 and follow-ups #2714/#2715 merged previously; version-display PR #2719 merged through Merge Queue at `aa1549894834ba4ba6d855d8ddee7252f58dddc7`
- Source repository PR / main / Release: userscript PR #32; current Release `v2.9.39` targets `cb30da99bce3a02295863cfb9d74c592947e0a42`; Chrome distribution PR #2 merged at `dc24b66640a719b7742c84d30bb7c84483fd55e9`, Release `v0.6.14` (ID `391653936`)

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
7. 当目录仍显示旧基线而脚本已通过自身更新 URL 安装新版本时，Marketplace 卡片主版本
   显示脚本元数据版本；未安装时才显示目录基线，不能再出现 `2.9.37` 与 `2.9.39`
   并列造成的误导。

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
- [Violentmonkey](https://github.com/violentmonkey/violentmonkey), MIT, inspected at
  `1fed91eabe35c9724e2c7858f2b24ad6844de7d`: its installed-script view renders the script's
  parsed `meta.version`, while `src/background/utils/update.js` resolves `@updateURL` and
  `@downloadURL` for update checks. This confirms the separation needed here; no code copied
  and no dependency added.
- Reuse decision: retain Fabushi's existing `normalizeUserScript`, `userScripts` runner and
  bounded GitHub/raw-host security boundary; replace only the fixed-catalog version decision
  for userscripts with metadata URL discovery and preserve the package updater contract for
  non-userscript artifacts.

## Implementation summary

Implemented in the task worktree and independent Chrome distribution repository: metadata URL
parsing, metadata-authoritative versions, record provenance fields, direct update URL discovery
with backward-compatible derivation from the old pinned raw artifact, remote source size/identity
checks, automatic installation and active-tab reactivation, stale-catalog UI handling,
catalog-independent userscript checks, and the card-version readout based on installed script
metadata. The independent package `v0.6.14` with bundled userscript `2.9.39` is published;
the same source is merged to canonical Fabushi `main`.

## Evidence, blockers and next action

- Local: changed extension modules pass `node --check`; the root host's focused Chrome tests
  pass `7/7`, and the independent repository's pure card-version regression passes `1/1` with
  `git diff --check`. No application build/package/E2E was run locally.
- Source repository CI/Release: userscript PR #32 merged; Release `v2.9.38` was previously
  verified. The current live source release is `v2.9.39`, targeting
  `cb30da99bce3a02295863cfb9d74c592947e0a42`, with stable `@updateURL`/`@downloadURL` and
  asset size `237771` bytes.
- Independent Chrome distribution: `bhrumom/fabushi-chrome-extension` PR #1 merged at
  `5a83c837f8fff27cc57c0f2fc9e0db5d13ce9665`; release workflow `35346479236` passed and
  published `v0.6.13` with `fabushi-chrome-0.6.13.zip`.
- Local Chrome readback: extension ID `gdoggbammnghfbdcmlngjcbffblbllod`, original directory
  `/Users/gloriachan/Downloads/fabushi-0.3.0`, Chrome detail page showed `0.6.13` after reload,
  and the bundled script showed `2.9.38` with stable raw `@updateURL`/`@downloadURL`. The prior
  directory is recoverable at `/Users/gloriachan/Downloads/fabushi-0.3.0.backup-0.6.9-20260918-204801`.
- Canonical-main package evidence: `Chrome Extension Package (zero-test)` run `35349390987` passed for source SHA `42b8bacf6f41718da342f3c3c71114045a18ea68` and produced the exact `0.6.13` package/provenance bundle; post-package trigger `35349418461` passed.
- Required interactive packaged journey / screenshot-video-trace-report evidence remains pending for this task; no local build or E2E was run.
- Web Store publish workflow `35349440443` failed closed with HTTP 400 `NOT_UPDATEABLE`: the existing item is currently in review. This is an external review blocker, not a package/version failure.
- Canonical-main delivery readback is recorded below; the required interactive packaged journey
  visual/debug bundle remains open, and the Web Store review remains an external blocker. This
  task therefore stays `IN_PROGRESS` even though the independent Release and local Chrome fix
  are verified.
