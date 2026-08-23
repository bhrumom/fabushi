# 2026-08-23 Build/Test Efficiency Requirement

## Original user requirement

目标：为 Fabushi 建立长期的全平台构建与测试效率优化工作流，使后续每一轮 GitHub Actions 构建尽可能从上一轮可复用的结果继续，而不是无条件从零开始全量编译。

用户明确要求：

1. 全平台安装包构建必须最大化跨 workflow run 的缓存复用，效果接近“热更新”：只修改少量代码时，优先复用上一轮依赖、编译中间产物、原生二进制/静态库、Gradle/Xcode/Cargo/Node 构建缓存，只重建受影响部分。
2. 项目目标是同时提高安装包构建速度与自动化测试效率。
3. PR/CI 阶段只做快速检查，不运行 E2E，不进行全平台安装包构建，也不进行 Debug 安装包构建。
4. 只有变更通过受保护流程合并进入 `main` 后，才运行：
   - 受影响平台安装包构建；
   - Debug 包构建；
   - 自动化端到端测试（E2E）。
5. 任何增量/缓存优化都不能通过跳过必要安全检查、签名/发布门禁或降低主干质量来换速度。

## Normalized interpretation

“热更新式构建”在 GitHub-hosted ephemeral runner 上实现为可恢复、内容寻址、分层的跨运行缓存与产物复用，而不是假设 runner 本机工作区会永久保留。缓存必须由工具链版本、平台、架构、锁文件、关键源码与构建配置共同决定失效边界；缓存命中失败时必须正确回退到可重复的干净构建。

## Durable routing

该要求属于既有 `FAB-P0003 / FCM` 的 CI/CD 延迟、缓存、构建/测试分层后续阶段。既有范围文件已明确允许继续进行 cache/build/test decomposition，因此复用 `projects/fabushi-cicd-merge-governance/`，不创建重复 Portfolio Project ID。
