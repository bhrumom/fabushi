# 持续集成 (CI) 与小程序云端构建更新上线 PRD

## 1. 需求概述
为确保前期完成的“全球法布施小程序 UI 规范对齐（Telegram 毛玻璃风格）”与“桌面端 Rust Worker 一次性预编译去发热优化”能够全面生效并服务所有终端用户，现需启动自动化持续集成（CI）流水线，通过 Git 提交与分支同步触发云端自动化构建与生产环境部署，将小程序最新代码与静态资源发布上线。

## 2. 现状分析与涉及文件
目前本地在 `feat/merge-miniapp-sdk` 分支下完成了以下关键模块的开发与修改，尚未同步至线上生产环境：
1. **核心小程序业务与 UI 重构**：
   - `frontend/apps/web/src/app/miniapps/[id]/GlobalDharmaApp.tsx` (卡片界面规范化与 UI 重构)
   - `frontend/apps/web/src/app/miniapps/[id]/global-dharma-send-service.ts` (Rust Worker 预编译及直接执行二进制优化)
   - `frontend/apps/web/src/app/miniapps/[id]/miniapps.css` (全局小程序 UI 样式系统)
2. **系统架构与指南文档**：
   - `docs/global-dharma-rust-runtime-miniapp.md` (架构及最佳实践记录)
3. **配套新小程序与微信端映射**：
   - `frontend/apps/web/src/app/miniapps/[id]/HermesInstallerApp.tsx` 等配套扩展

## 3. CI 流水线触发机制与部署架构
本项目已在 `.github/workflows/` 下配置了成熟的 Cloudflare 自动部署工作流：
- **小程序构建与托管** (`deploy-miniapps-cloudflare.yml`)：
  - 触发条件：推送代码至分支且变更涉及 `frontend/apps/web/**` 或依赖项。
  - 执行动作：云端配置 Node.js 20 & pnpm 10，自动执行 `pnpm --filter @fabushi/web build`，将其打包产物发布至 Cloudflare Pages (`fabushi-miniapps`)。
- **官网全站上线** (`deploy-official-site-cloudflare.yml`)：
  - 触发条件：代码合并/同步至 `main` 分支。
  - 执行动作：全量构建应用并同步更新至 `https://fabushi.ombhrum.com` 生产网关。

## 4. 实施步骤与任务分解 (Task List)
严格遵循渐进式与自动化原则，实施计划分为以下四个步骤：
- **步骤 1：本地代码审计与变更暂存**：检查当前工作区的变动文件，确保无遗漏，将其规范添加并提交至当前开发分支。
- **步骤 2：分支同步与远程合并**：将当前本地分支的提交推送至 GitHub 远程仓库，并同步合并至 `main` 主分支，按需触发 CI 工作流。
- **步骤 3：云端 CI 自动化流水线追踪**：监控 GitHub Actions 触发的 `deploy-miniapps-cloudflare.yml` 与 `deploy-official-site-cloudflare.yml` 构建状态，确保云端编译无语法和打包异常。
- **步骤 4：线上产物验证与闭环汇报**：确认自动化部署完成后，检查线上接口与静态资产访问状态，并在验收通过后更新最终闭环任务记录。

## 5. 验收标准
1. Git 提交清晰规范，所有代码变动完整同步至 `main` 生产分支；
2. GitHub Actions CI 流水线成功跑通（绿标），Cloudflare Pages 成功生成新版本部署预览与线上产物；
3. 线上小程序页面能够正确加载最新构建的 Web/Worker 静态资产。
