# TFI-M6-MAINSAFE-001-OWNERSHIP-001 测试发布变更日志

日期：2026-09-05（+08:00）

本文件只记录测试发布会话执行的 GitHub/Actions/记录动作，不表示新增产品代码。

## 动作日志

1. 重新读取并核对 root `AGENTS.md`、`projects/PORTFOLIO.json`、TFI `SOURCE_OF_TRUTH.md` / `PROJECT.yaml` / `README.md`，以及 OWNERSHIP-001 架构、执行、复审 task/evidence/status/changelog。
2. 重新核对产品 PR #2336、架构 records-only PR #2337、reviewer records-only PR #2338、review comment `5546493085`、ruleset 和 PR-head/queue Actions。
3. 确认 `main-merge-queue` ruleset id `15857448` 对 `main` 强制 `SQUASH + ALLGREEN` 且 required status 为 `CI result`，无可用 bypass。
4. 仅为产品 PR #2336 添加仓库规定的 `automerge` 标签。未 direct merge、未 force-push、未 rebase、未 retarget、未复用旧 #2323 stack。
5. Explicit automerge run `33920248647` / job `101176673378` 将 reviewed exact head `8760b7587f6d576262e5993a72b5c5112ff595db` 合法送入 merge queue。
6. GitHub 生成 merge-group SHA `dbf22b467d35c8af2a074896c355a41993c8c191`；canonical queue CI run `33920323994` 与 fallback run `33920289602` 的 required `CI result` 均 SUCCESS。
7. #2336 合并后重新读取 canonical `main`，accepted SHA 精确为 `dbf22b467d35c8af2a074896c355a41993c8c191`。
8. 仅使用该 accepted SHA 的 main-push Actions 作为 packaged/native acceptance 来源：
   - Electron desktop `33920502884`: FAILURE；Linux job `101177474099` 因 iOS build number 29/28 漂移在 package/E2E 前失败；macOS/Windows packaged journeys PASS。
   - Messaging Product Gate `33920502888`: SUCCESS。
   - Native mobile `33920502967`: FAILURE；Android PASS；iOS job `101177474816` 的 messaging simulated-user UI test FAIL。
9. 下载并检查 macOS/Windows desktop diagnostics artifact 目录结构和 Android reports artifact 目录结构，以核对实际 video/trace/screenshot/log/report/APK 证据类型。
10. 因 required packaged/native/evidence gate 不满足，未创建 test tag、pre-release、release assets 或 stable release，未进行代码审查组视频复核交接。
11. 创建本轮 records-only 分支 `test-release/tfi-m6-mainsafe-001-ownership-001-packaged-blocked-20260905`，只写入 `projects/telegram-fabushi-integration/**` 测试发布记录。

## 产品与工作流变更

- 应用源码：无
- 测试源码：无
- workflow：无
- version config：无
- canonical main 直接写入：无
- 正式发布：无

## 结果

`TEST-FAILED / PACKAGED-BLOCKED / NATIVE-IOS-FAILED / EVIDENCE-INCOMPLETE`
