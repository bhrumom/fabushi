# Mahayana 运行时集成与桌面安装包发布需求文档 (PRD)

## 1. 背景与目标
为了支持大乘 CLI 与全局法布施应用整合、内置 Codex 执行环境并打通好友/私信及支付宝鉴权体系，完成了多平台的依赖整合与运行时对接。
本目标是将当前分支 `codex/mahayana-runtime` 上的所有变更提交并推进合并至主分支 `main`，同时跟踪触发安装包打包构建与发布。

## 2. 变更范围与详细模块
1. **大乘原生核心与命令行工具 (Rust & CLI)**
   - `native/mahayana-cli` / `native/mahayana-wrapper`: 增加 `product.rs` 模块，集成 Codex 安装包及运行逻辑，并完善所有通过命令测试的集成用例。
2. **多终端原生构建与运行时集成**
   - `fabushi/lib/services/`: 增加 `mahayana_command_service.dart`、支付宝鉴权服务、好友私信及 Telegram 运行时适配。
   - `fabushi/macos` / `fabushi/linux` / `fabushi/windows` / `fabushi/ios` / `fabushi/android`: 完整对接构建与动态链接配置。
3. **前端应用与数据库定义**
   - `fabushi/web/migrations/20260713_friends_and_direct_messages.sql`: 新增好友关系与私信表持久化。
   - `fabushi/web/src/handlers`: 新增好友管理处理逻辑及相关测试覆盖。
4. **CI 与安装包发布工作流**
   - `.github/workflows/desktop-installers.yml`: 自动化构建与安装包打包 CI。
   - `scripts/install-mahayana.sh` & `.github/scripts/build-mahayana-desktop-bundle.sh`: 桌面端构建打包脚本。

## 3. 验证与测试标准
- **本地自动化测试通过率**：
  - Rust CLI 集成测试：`cargo test --manifest-path native/mahayana-cli/Cargo.toml` 8 个用例全部通过。
  - Web 契约与单元测试：`node --test fabushi/web/tests/alipay-cli-session.test.js fabushi/web/tests/friends-and-messages-contract.test.js` 9 个用例全部通过。
- **发布构建确认**：
  - 代码推送到 GitHub 后，确认是否有待处理的 PR 或直接并入 main 分支触发 GitHub Actions。
  - 跟踪 CI / 安装包构建与发布的运行与结果。

## 4. 执行路线图
1. 构思方案并生成 PRD 文档（本步骤）。
2. 提请用户审核确认提交及发布方案。
3. 执行 Git commit 提交本地更改。
4. 推送到远端仓库，创建或自动合并 PR 至 main / 跟踪桌面安装包构建动作。
