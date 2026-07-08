# 代码提交、跟踪合并与部署执行计划 (PRD)

## 1. 需求与目标
本任务的目标是**跟踪并推动 PR #1532 ("feat(miniapp): 升级全球法布施无盘内存推流与代理白名单支持全端 Codex 集成") 完成 CI 自动化测试通过、安全合并至 main 分支，并最终跟踪完成生产环境部署**。

## 2. 前期调研与疑点分析 (First Principles)
通过调研 GitHub CLI PR 状态与 Workflow 运行日志，当前阻碍 PR 合并与部署的核心疑点与阻塞项如下：

### 2.1 Rust Codex Wrapper CI 编译错误 (`codex-wrapper`)
- **错误现象**：`Test Universal Codex Rust Wrapper (ubuntu-latest)` 等 CI Job 在执行 `cargo clippy` 时因开启了 `-D warnings` 导致构建失败。
- **根本原因**：
  1. `native/codex-wrapper/src/model.rs` 中 `UniversalModelGateway::new()` 未实现 `Default` trait (`clippy::new_without_default`)。
  2. `native/codex-wrapper/src/sandbox.rs` 中 `VirtualVfs::new()` 未实现 `Default` trait (`clippy::new_without_default`)。
  3. `native/codex-wrapper/src/transport.rs` 中使用 `.map(|msg| Ok(msg))` 触发了闭包冗余警告 (`clippy::redundant_closure`)。
- **解决方案**：
  1. 在 `model.rs` 为 `UniversalModelGateway` 添加 `impl Default for UniversalModelGateway`。
  2. 在 `sandbox.rs` 为 `VirtualVfs` 添加 `impl Default for VirtualVfs`。
  3. 在 `transport.rs` 将 `.map(|msg| Ok(msg))` 简化为 `.map(Ok)`。

### 2.2 Worker 契约测试 CI 偶发序列化失败
- **错误现象**：`Contract checks - Worker` 在 CI (Node.js 24 环境) 执行 `tests/alipay-user-id.test.js` 时抛出 `Unable to deserialize cloned data due to invalid or unsupported version`。
- **根本原因**：Node 24 的内置 `test_runner` 在使用 `--test-concurrency=1` 处理多文件管道并发输出时，对带有特殊结构的 Console Log / IPC 消息进行 structured clone 序列化解析时存在内部 Buffer 处理差异。
- **解决方案**：
  1. 优化 `ci.yml` 中的契约测试执行方式（如将 `xargs -0 node --test` 调整为 `xargs -0 -n 1 node --test` 以单文件进程隔离完全避免多文件 IPC 数据包解析缓冲冲突）。
  2. 本地自动运行所有契约测试验证稳定性。

## 3. 执行方案与流程 (构思方案 → 提请审核 → 分解为具体任务)
严格按照以下顺序推进：
1. **方案提请审核**：向用户展示分析与执行路线图。
2. **任务分解与自动化开发测试**：
   - [ ] 修改 `native/codex-wrapper` 相关代码，解决 Clippy 警告。
   - [ ] 优化 `.github/workflows/ci.yml` 中 Worker 契约测试执行指令，保障 Node 24 下 IPC 传输稳定。
   - [ ] 运行本地自动化测试（Cargo check/clippy + Node tests）。
3. **提交代码与持续监控 CI**：
   - [ ] 将变更 commit 并 push 至远程分支 `docs/update-prd-sequential-sending`。
   - [ ] 监控 GitHub Actions 各种检查直到全部绿色通过。
4. **自动合并与跟踪部署**：
   - [ ] 确认 PR #1532 满足所有分支保护规则后触发自动合并（或执行 gh pr merge）。
   - [ ] 监控 Cloudflare Pages / Worker 及对应部署流水线，验证最终上线状态。
   - [ ] 完成后更新技术文档与问题排查记录。

## 4. 验收标准
- 所有 CI 流水线（特别是 Rust Wrapper 与 Worker Contract checks）100% 通过。
- PR 成功合并至 `main` 分支，无任何冲突或残留报错。
- 生产部署流水线触发并执行完成，应用正常可访问。
