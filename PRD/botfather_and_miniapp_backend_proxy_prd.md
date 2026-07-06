# 机器人之父与沙箱小程序后端请求代理修复 PRD

## 1. 问题背景与现象分析 (Problem Analysis)
用户反馈在桌面端小程序沙箱中与「机器人之父」(Bot Father) 对话发送消息时，出现错误：
`生成失败: Bad state: This Cloudflare Worker is an API backend only.`

### 1.1 根本原因剖析 (First Principles Thinking)
1. **网络请求流向**：
   在 Flutter 端，与「机器人之父」聊天时，代码 `codex_sdk_service.dart` 和 `social_feature_chat_screen.dart` 中调用了 endpoint：
   `AppConfig.buildBackendUri('/api/botfather/generate-miniapp')`
   同时在加载沙箱小程序列表时，调用了 endpoint：
   `AppConfig.buildBackendUri('/api/miniapps/registry')`
   这些请求都会首先到达 Cloudflare Worker 路由（即 `api.ombhrum.com`，对应 `fabushi/web/worker-modular.js`）。

2. **路由拦截与转发机制**：
   在 Cloudflare Worker 中，通过 `isDachengAiPath(pathname)` 判断是否将 `/api/xxx` 代理转发至后端 AI 服务 (`ai-backend` / `ai.ombhrum.com`)。
   当前 `fabushi/web/src/handlers/dacheng-ai.js` 中的 `isDachengAiPath` 仅包含以下前缀：
   - `/api/ai/`
   - `/api/agent/`
   - `/api/openclaw/`
   - `/api/resources/`
   - `/api/codex/resource-task`
   
   **遗漏项**：`/api/botfather/` 与 `/api/miniapps/`。
   
3. **报错触发**：
   由于 `/api/botfather/generate-miniapp` 未被判定为 AI 后端路径，Cloudflare Worker 无法将其转发给 `ai-backend` 节点服务，最终落入 `worker-modular.js` 的兜底路由，返回 404 及文本 `"This Cloudflare Worker is an API backend only."`。Flutter 端解析 json 后抛出 StateError 异常显示在界面上。

---

## 2. 解决方案与具体任务 (Proposed Solution & Tasks)

### 2.1 构思方案
遵循 KISS (Keep It Simple, Stupid) 原则，在不引入任何复杂或冗余机制的前提下，直接完善 Worker 层的路由白名单定义：
1. **修改路由判断函数**：在 `fabushi/web/src/handlers/dacheng-ai.js` 的 `isDachengAiPath` 中加入 `pathname.startsWith('/api/botfather/')` 和 `pathname.startsWith('/api/miniapps/')`。
2. **补充自动化单元测试**：在 `fabushi/web/tests/dacheng-ai-handler.test.js` 中新增针对 `/api/botfather/generate-miniapp`、`/api/miniapps/registry` 和 `/api/miniapps/dev/create` 的断言测试，确保不再产生回归问题。
3. **回归验证**：调用自动化测试命令 `node --test fabushi/web/tests/*.test.js` 验证修改通过。

---

## 3. 任务清单 (Task List)
- [x] 任务 1：修改 `fabushi/web/src/handlers/dacheng-ai.js`，将 `/api/botfather/` 与 `/api/miniapps/` 纳入代理路由前缀。
- [x] 任务 2：更新 `fabushi/web/tests/dacheng-ai-handler.test.js` 单元测试文件，增加相关 API 路径路由识别的测试用例。
- [x] 任务 3：运行自动化测试执行验证，确保所有 Worker 相关测试 100% 跑通，并在完成后更新规范文档。

---

## 4. 执行结果与测试报告 (Execution Results & Test Report)

### 4.1 自动化测试执行记录
- **执行命令**：`node --test fabushi/web/tests/*.test.js`
- **执行结果**：
  ```
  ℹ tests 76
  ℹ suites 0
  ℹ pass 76
  ℹ fail 0
  ℹ cancelled 0
  ℹ skipped 0
  ℹ todo 0
  ℹ duration_ms 4793.310959
  ```
- **测试通过率**：100% (共 76 个测试用例全部通过，相比修复前新增的 1 个关于 `Bot Father and MiniApp registry endpoints` 的复合测试断言顺利通过)。

### 4.2 过程总结
整个流程严格执行了“第一性原理剖析定位 → 制定 KISS 修复方案 → 编写 PRD 并提交审核 → 代码修改与添加单元测试 → 命令行全自动测试回归”的结构化研发步骤。修复完全解决了由于路由拦截白名单遗漏导致的 API 请求代理报 404 错误的问题。
