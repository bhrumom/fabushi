# M8-MARKET-003 — 全平台 GitHub 安装更新证据索引

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M8-MARKET-003`
- **Product implementation branch**: `codex/tfi-miniapp-unified-install-update-20260913`
- **Records branch**: `codex/tfi-market-003-record-closure-20260914`
- **Implementation / repair commits**: `3cd8ba783`, `cc23420c56c98f7857b731832281c212203ce60c`, `85b3a8b258269e9d4e234e648d086653146ffc82`
- **Accepted product SHA**: `f6a0d99c85a481999298a18cada6a9f10718a360`
- **Test release**: `1.2.65`
- **状态**: `RELEASED`
- **创建日期**: `2026-09-13`
- **Product PR chain**: [#2578](https://github.com/bhrumom/fabushi/pull/2578), [#2579](https://github.com/bhrumom/fabushi/pull/2579), [#2581](https://github.com/bhrumom/fabushi/pull/2581), [#2582](https://github.com/bhrumom/fabushi/pull/2582), [#2583](https://github.com/bhrumom/fabushi/pull/2583), [#2585](https://github.com/bhrumom/fabushi/pull/2585), [#2586](https://github.com/bhrumom/fabushi/pull/2586), [#2590](https://github.com/bhrumom/fabushi/pull/2590), [#2591](https://github.com/bhrumom/fabushi/pull/2591), [#2592](https://github.com/bhrumom/fabushi/pull/2592), [#2593](https://github.com/bhrumom/fabushi/pull/2593), [#2596](https://github.com/bhrumom/fabushi/pull/2596), [#2597](https://github.com/bhrumom/fabushi/pull/2597), [#2598](https://github.com/bhrumom/fabushi/pull/2598), [#2599](https://github.com/bhrumom/fabushi/pull/2599)

## 目标与证据边界

本目录记录“市场只发布元数据、客户端从不可变 GitHub 版本取包并校验、所有平台共享安装/更新/回滚状态”的实现证据。截图中的 Chrome Marketplace 仅是产品形态参考，不是代码或操作指令。

可执行包的正式路径是：Marketplace release metadata → GitHub commit/release artifact → Host 下载 → SHA-256/size 校验 → staging → active pointer。Web 页面只记录版本、来源和摘要；没有 Native Host 时不得把 metadata 记录宣传为已安装可执行包。Chrome 用户脚本由用户显式点击后从固定 `raw.githubusercontent.com` 地址取回，并在扩展内校验后交给 userscript runtime。

## 已完成的实现面

- Node Marketplace：统一发布合同 `fabushi.marketplace.install.v1`，公共 GitHub repository + 40 位 commit `sourceRef`，artifact SHA-256/size/format/entry/runtime/platforms，平台筛选和非 GitHub 拒绝。
- Rust Runtime/Host：合同校验、GitHub 来源约束、下载后二次 SHA-256/size 校验、版本单调更新、`previous-active.json` 和显式 rollback。
- Desktop/Chrome/Web/Android/iOS/CLI：共用 release/install/update 语义；Chrome 用户脚本支持 pinned raw GitHub artifact；Web 执行包安装要求 Host。
- Marketplace UI：显示 GitHub 来源、commit 前缀、版本、权限/发布说明入口，并区分安装、更新、重新安装、当前最新、阻止降级和等待 GitHub 发布。
- Fixed official catalog: `faliu-flashcards`, `hermes-installer` and `chatgpt-auto-confirm` invalid/mismatched archives were revoked and CI-rebuilt as `1.0.1`; the immutable package Release is [marketplace-v1.0.1-cc23420c56c9](https://github.com/bhrumom/fabushi/releases/tag/marketplace-v1.0.1-cc23420c56c9).

## 轻量检查

| 检查 | 结果 | 备注 |
|---|---|---|
| `git diff --check` | PASS | 产品实现和后续记录变更均通过轻量空白检查 |
| Chrome JS syntax | PASS | `app.js`、`marketplace-install.js`、`userscript-core.js` |
| Chrome contract/platform tests | PASS `11/11` | Node targeted tests |
| Backend pure marketplace tests | PASS `9/9` | `ai-backend/test/miniapp_marketplace.test.js` |
| Backend HTTP test | NOT RUN | checkout 缺少 `express`，未安装依赖 |
| Rust/Next/Electron/mobile build/E2E | PASS in GitHub Actions | 本地未构建；准确主线的 packaged journeys 见下方运行与 job 证据 |

## 已关闭的发布数据风险

只读核对发现固定 `marketplace/packages` 目录存在历史问题：`chatgpt-auto-confirm`、`faliu-flashcards`、`hermes-installer` 的 `app.tar.gz` 未通过 gzip 校验，且 catalog SHA-256/size 与 checked-in bytes 不一致。该风险已由 PR [#2590](https://github.com/bhrumom/fabushi/pull/2590) 的 CI 受控重打包、PR [#2591](https://github.com/bhrumom/fabushi/pull/2591) 的 manifest/source binding 和 workflow [34769542406](https://github.com/bhrumom/fabushi/actions/runs/34769542406) 关闭；旧版本未被覆盖，新的 `1.0.1` Release 资产已重新核验。

修复版 package assets（均来自 source commit `cc23420c56c98f7857b731832281c212203ce60c`）：

| Artifact | Size (bytes) | SHA-256 |
|---|---:|---|
| `chatgpt-auto-confirm-1.0.1.tar.gz` | 983 | `ce5beae5f3b8a29dccb65cb91744f2a82bb19186c3f7031ca75f405ab4effb76` |
| `faliu-flashcards-1.0.1.tar.gz` | 1729 | `fb2a8fa187fde312069c9facb49657c366cfa4176f27a90abff5aa407e260356` |
| `hermes-installer-1.0.1.tar.gz` | 1731 | `e693cb2378d580cb86d88fb391a04b8c96dcf6614b445c32339bfb7358e0c4cd` |
| `official-marketplace-release-manifest.json` | 2042 | manifest records the same package hashes and sizes |

## PR、主线与工作流证据

- The full protected product chain is recorded in the task record. The final trigger/version merges are [#2596](https://github.com/bhrumom/fabushi/pull/2596) → `91521e88…`, [#2597](https://github.com/bhrumom/fabushi/pull/2597) → `942cefe7…`, [#2598](https://github.com/bhrumom/fabushi/pull/2598) → `845fccec…`, and [#2599](https://github.com/bhrumom/fabushi/pull/2599) → accepted `f6a0d99c85a481999298a18cada6a9f10718a360`.
- Merge-group/CI evidence: [34799981704](https://github.com/bhrumom/fabushi/actions/runs/34799981704) and [34799982178](https://github.com/bhrumom/fabushi/actions/runs/34799982178) passed.
- Exact accepted SHA workflows: Chrome [34800013075](https://github.com/bhrumom/fabushi/actions/runs/34800013075), Native mobile [34800013089](https://github.com/bhrumom/fabushi/actions/runs/34800013089), Electron [34800013097](https://github.com/bhrumom/fabushi/actions/runs/34800013097), Global Dharma evidence publish [34800500538](https://github.com/bhrumom/fabushi/actions/runs/34800500538), and post-main delivery [34800500558](https://github.com/bhrumom/fabushi/actions/runs/34800500558) all passed.
- Packaged jobs: Electron macOS `103840631203`, Linux `103840631401`, Windows `103840631412`; Native Android `103840630838`, iOS `103840631007`; Chrome package `103840630671`; post-main gate `103842055345`, publish `103842076233`.

## Mandatory visual/debug evidence bundle

The exact Electron packaged journeys retained step-labelled screenshots, complete operation video, Playwright trace/HTML reports and diagnostics on the always-upload path. Native evidence retains Android instrumentation reports/logcat/debug material and iOS `.xcresult`; Chrome retains the packaged extension/content manifest and package evidence. Artifact names and IDs are tied to the exact SHA/run and all have 90-day retention (expiry `2026-12-13`):

| Platform / purpose | Artifact IDs |
|---|---|
| Electron packages and diagnostics | `10330992099`, `10331016984`, `10331361708`, `10331366828`, `10331600952`, `10331645539`, `10331680984` |
| Android/iOS native reports | `10331116764`, `10331631060` |
| Chrome exact-source package | `10331530747` |
| Post-main source binding and delivery bundle | `10330783065`, `10331456743` |

The earlier exact-main Electron failure (`stale_app_surface_generation`) was retained, diagnosed, and fixed in PR [#2596](https://github.com/bhrumom/fabushi/pull/2596); the final rerun passed. This preserves failure evidence rather than converting it into an unqualified success.

## 结果

`M8-MARKET-003` 的 `PR → protected main → exact canonical SHA → packaged E2E/evidence → Release` 已闭合。Release [desktop-1.2.65](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65) 于 `2026-09-14T02:50:58Z` 发布，`target_commitish` 精确等于 `f6a0d99c85a481999298a18cada6a9f10718a360`，并包含 macOS DMG/ZIP、`latest-mac.yml`、blockmap、Windows/Linux 安装包与 updater metadata、SHA256 manifests 及 Chrome 包/content manifest。

最终 Release 自引用检查通过：`SHA256SUMS.txt` 与 `fabushi-chrome-SHA256SUMS.txt` 均不把自身列入校验；Linux/macOS/Windows delivery manifests 的版本、source SHA 一致为 `1.2.65` / `f6a0d99c…`。旧客户端 updater 下载/安装/重启回归未运行，因为它按本任务策略属于 advisory、非必需门禁；Chrome Web Store 真实公开提交同样未尝试，受保护凭据缺失不影响本次测试 Release。
