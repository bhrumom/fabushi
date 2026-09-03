# 2026-08-24 — 旧版 App 更新链验证改为可选

项目：`FAB-P0003 / FCM`
来源：用户最新明确澄清

## 最新要求

用户明确澄清：

> 验证旧版 App 能发现新版、头像旁出现更新入口、点击后下载/安装/重启，不用必须去做。

因此，先前 `source/2026-08-24-main-e2e-release-open-source-first.md` 中把“旧版 App → 新版 Release 的真实更新链”作为每个任务强制完成条件的解释被本文件覆盖。

## 规范化语义

1. PR 合并到 canonical `main` 后的快速可安装包构建、打包后模拟用户 E2E、失败修复重跑、全部 required E2E 通过后发布 GitHub Release，仍然是强制门禁。
2. Release 仍必须保留正常桌面更新能力所需的版本与 updater 资产/元数据；不能因为更新链验证变为可选而破坏 `electron-updater` 兼容性。
3. “从上一版已安装 App 启动 → 发现新版 → 显示头像/个人资料旁更新按钮 → 点击 → 下载 → 安装/替换 → 重启”的端到端升级验证改为**可选/建议性验证**，不再是每个任务、每个 Release 或 FCM-009 关闭的硬门禁。
4. 现有 updater E2E 可以继续作为回归诊断、发布后抽样、更新系统改动时的专项验收或人工触发验证；它失败时应记录证据并在相关更新功能任务中修复，但不能仅因这一可选验证失败就阻止一个与 updater 无关、且 required post-main E2E 已通过的任务完成。
5. 当任务本身修改自动更新逻辑、更新按钮、版本比较、下载/安装/重启机制或 updater 元数据时，应在该任务自己的 acceptance criteria 中按风险显式决定是否把升级 E2E 提升为该任务的 required gate；默认不强制。
6. 本澄清只放宽“旧版真实升级链验证”这一项，不放宽 open-source-first、PR-to-main、required packaged E2E、Release、签名/公证、版本单调性、updater 资产完整性或 warm-build/缓存完整性要求。
