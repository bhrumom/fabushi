# TFI-USERSCRIPT-RECOVERY-017 — Marketplace 线上 userscript 发现修复

- 项目：`FAB-P0001` / `TFI`
- Task ID：`TFI-USERSCRIPT-RECOVERY-017`
- 来源：`source/2026-09-15-marketplace-userscript-live-discovery.md`
- 状态：`IN_PROGRESS / FOLLOWUP_PR_PENDING`
- 开始时间：2026-09-15（Asia/Shanghai）
- 最近更新：2026-09-15（生产 catalog 已回读）

## 目标

让仍运行旧版内置 Marketplace fallback 的 Chrome 扩展，从公开控制面发现独立 userscript `v2.9.30`，并让插件主动、持续地提示更新，而不把桌面 Mini App 的 `1.0.1` 包版本误当作网页脚本版本；保持 GitHub immutable source、SHA-256/size 校验和桌面/CLI 兼容性。

## 范围

包含 Mahayana platform Worker 的 Chrome-only Marketplace projection、`v2.9.30` sourceRef/Release URL/asset digest/size 固定值、Chrome Service Worker 定时/启动检查、Marketplace 页面即时检查与更新提示、扩展版本 `0.6.6`、直接 release metadata 回读和回归测试、项目记录及生产部署回读。

不包含 Chrome Web Store 审核状态、Tampermonkey 本机安装确认、桌面 Mini App 版本升级、绕过 ChatGPT 账户级限流或放宽客户端 artifact 校验。

## 依赖

- 依赖 `TFI-USERSCRIPT-RECOVERY-016` 的 source main `480ebe61ba039f15e7023bbc0253ea23c373aba0` 与 userscript Release `v2.9.30`。
- 依赖 canonical `main` 的 protected merge、Platform Control Plane CI/部署和线上 API 回读。
- 本机低磁盘约束：不执行 Cargo build/test 或应用 E2E；重型验证由 GitHub Actions 完成。

## 验收标准

1. `GET /v1/marketplace/plugins?platform=chrome-extension` 对 `chatgpt-auto-confirm` 返回 `latestVersion=2.9.30`、userscript surface、immutable GitHub sourceRef、asset URL、size `224113` 和 SHA-256 `d15040a5…`。
2. 同一插件的桌面/CLI 查询仍返回现有 Mini App 包，不受 Chrome-only projection 改写。
3. Chrome 客户端把远端 `2.9.30` 置于旧 bundled `2.9.28` 之上，显示“更新”而不是“已是最新”，并在安装前通过 URL、size、SHA-256 和 userscript header 校验。
4. Service Worker 在启动/安装及每 30 分钟 alarm 自动检查并保存状态；打开 Marketplace、点击“立即检查”或每 5 分钟页面刷新会显示远端结果，发现更新时 action 徽章和页面状态均提示更新。
5. `GET /v1/marketplace/plugins/chatgpt-auto-confirm/releases/2.9.30` 返回同一 release metadata；未知/旧版本路径保持既有数据库行为。
6. Platform Control Plane CI、Chrome 包 CI、受保护主线、生产部署和线上 API smoke 回读全部通过；部署证据按 canonical main SHA 保留。

## 验证方法

- 轻量本机：`rustfmt --check`、`git diff --check`、静态审阅；不运行 Cargo 或应用构建。
- GitHub Actions：Platform Control Plane Rust unit/wasm check、架构合同和生产 deploy smoke；必要时运行 Chrome Marketplace contract。
- 线上：回读 `api.ombhrum.com` Chrome catalog 与 direct release metadata，检查 v2.9.30/sourceRef/hash/size/artifact URL。

## 开源优先调查与决策

沿用 `TFI-USERSCRIPT-RECOVERY-016` 记录的 Kubernetes workqueue、BullMQ delayed jobs、Temporal durable timers 调查。本轮采用相同的 immutable release metadata 适配思路，不引入动态 GitHub 分支或新的第三方运行时；Chrome projection 与桌面 catalog 分离，降低版本语义混淆。

## 实现摘要

- 在 `worker_api/marketplace.rs` 增加 Chrome-only userscript projection helper，固定 source commit、Release/asset URL、digest 和 size。
- Chrome catalog list route 在旧 D1 Mini App row 上覆盖为 userscript projection；direct v2.9.30 release metadata 走同一 helper。
- Chrome 扩展新增 `marketplace-update-check.js`，按版本优先、同版本 digest 兜底比较已安装记录，使用 `chrome.alarms`、本地持久化和 action 徽章；`app.js` 在启动/打开/定时刷新时展示状态。
- Chrome manifest 从 `0.6.5` 升至 `0.6.6`，打包清单、验证器、契约测试和 packaged E2E 版本读取改为同步新版本。
- 保留现有 D1 row、桌面/CLI release、GitHub artifact admission 和客户端校验路径不变。

## 分支 / 提交 / PR

- 分支：`codex/tfi-marketplace-live-discovery-017`
- 跟进分支：`codex/tfi-marketplace-live-discovery-017-status`
- 提交：待提交
- PR：待创建

## CI / 部署 / 线上证据

- Platform Control Plane PR CI：通过；PR #2641 / run `34921674552`
- canonical main：`4f484be2fd72f13289473f9c4917e03b78a92022`（PR #2641 已合并）
- 生产部署：通过；Platform Control Plane run `34922024310`
- 线上 catalog/release 回读：通过；详见 `evidence/TFI-USERSCRIPT-RECOVERY-017/2026-09-15-production-readback.json`
- Chrome `0.6.6` packaged artifact 与自动更新检查 UI/Service Worker 证据：Chrome run `34922024248` 成功，artifact `10378058000`；follow-up PR #2642 的状态保持修复待合并后复跑 required post-main evidence

## 风险与阻塞

- `R-TFI-USR-MKT-017-01`：未来 userscript Release 若只更新 source repo 而未更新 projection 常量，旧扩展仍会显示旧版本；缓解为把 projection 常量和 release 记录作为同一任务门禁。
- `R-TFI-USR-MKT-017-02`：桌面/CLI 与 Chrome runtime 共用 plugin ID；缓解为只在 `platform=chrome-extension` 分支投影，不修改 D1 latest pointer。
- 当前无外部阻塞；Chrome Web Store 审核和本机 Tampermonkey 更新属于独立开放事项。

## 下一步

第一版 PR #2641 已合并并完成生产 Worker 部署/API 回读，线上条目已从 `2.9.28/f09e2c5e` 变为 `2.9.30/480ebe61`；Chrome `0.6.6` 包已由 run `34922024248` 构建。当前跟进 PR #2642 只修正搜索/加载竞态下的全局更新提示保持；合并后需完成该 SHA 的 post-main packaged evidence。当前已安装的旧 Chrome 包仍需通过其分发渠道更新到 `0.6.6`，本机扩展重载/安装仍需用户在动作前明确确认。

## 时间

- started_at：2026-09-15T10:08:00+08:00
- updated_at：2026-09-15T10:08:00+08:00
- completed_at：N/A（任务进行中）
