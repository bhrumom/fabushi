# 同步 Main 最新代码需求与执行计划 (PRD)

## 1. 任务目标
将远端主干 `origin/main` 的最新代码同步合并入当前开发分支 `feat/merge-miniapp-sdk`，解决合并冲突，确保当前分支包含主干所有最新功能和修复，并在通过自动化测试验证后完成代码提交。

## 2. 现状调研与冲突分析
- **当前分支与主干状态**：
  - 当前分支为 `feat/merge-miniapp-sdk`。
  - 通过 `git fetch origin main` 获取到主干最新 Commit 为 `6376e6b4b Add T0278 juan 8 zhengxin merit benefits (#1412)`。
- **合并冲突根因分析**：
  - 在执行 `git merge origin/main` 时，有以下两个文件出现合并冲突：
    1. `native/miniapp-core/Cargo.toml`
    2. `frontend/apps/web/src/app/miniapps/[id]/GlobalDharmaApp.tsx`
  - 经深入对比与历史追溯发现，当前分支此前所做的修改（例如 Commit `f8e3e6d41 Fix mobile mini app chat composer` 对应的 PR #1408）此前均已通过合并/压缩方式进入了主干 `origin/main`。
  - 主干在后续合并了 PR #1411 (`Refactor global dharma sending`)，对全球法布施应用做了大规模重构，将其底层逻辑抽象到了新文件 `global-dharma-send-service.ts` 中，并重写了 `GlobalDharmaApp.tsx`。
  - 同理，`native/miniapp-core/Cargo.toml` 在主干中新增了 `base64`、`once_cell`、`serde_json` 三個依赖以支持新的 FFI 和功能。

## 3. 冲突解决方案
由于当前分支截至 `f8e3e6d41` 的修改内容和目标均已经在主干中以最新架构形式演进和存在，解决冲突的最优策略遵循以主干最新架构为准：
1. **解决依赖配置冲突**：`native/miniapp-core/Cargo.toml` 直接采用主干新加入的依赖配置（对应 `--theirs` 版本）。
2. **解决 UI 与业务逻辑冲突**：`frontend/apps/web/src/app/miniapps/[id]/GlobalDharmaApp.tsx` 同样直接采用主干 PR #1411 重构后的最新完整版本（对应 `--theirs` 版本），避免使用已废弃的旧版调度接口和残留类型。

## 4. 分解任务清单
- [x] 1. 采用 `origin/main` 最新版本解决 `native/miniapp-core/Cargo.toml` 和 `GlobalDharmaApp.tsx` 的合并冲突。
- [x] 2. 使用 `git add` 标记冲突已解决，并执行测试命令对前端和 Rust 相关核心模块进行验证。
- [x] 3. 验证无误后，完成 Git 合并提交（Commit Merge）。
- [x] 4. 更新本 PRD 文档，记录整个同步合并与解决过程的最终验证结果。

## 5. 自动化测试与验证方案
- 运行前端构建/类型检查或测试，确保 React 组件及依赖引用正常无报错。
- 验证无误后完成合并并记录文档。

## 6. 执行过程记录与最终验证结果
在执行“完全同步 main 最新”过程中，遇到并解决了以下问题，自动化测试已全部跑通：
1. **合并冲突处理**：通过 `git checkout --theirs` 将冲突文件 `native/miniapp-core/Cargo.toml` 和 `frontend/apps/web/src/app/miniapps/[id]/GlobalDharmaApp.tsx` 切换至 `origin/main` 的最新代码并完成 `git add` 标记。
2. **Rust Cargo 语法错误修复**：在执行 `cargo check --manifest-path native/miniapp-core/Cargo.toml` 时，发现主干代码中 `src/lib.rs` 第 1180 行的 `"bot.close" => "请求关闭小程序。"` 末尾漏写了逗号（`,`），导致模式匹配语法错误。通过修改该文件补全逗号后，重新编译 `fabushi-miniapp-core` 和 `fabushi-miniapp-runtime` 两个包全部通过检查。
3. **Rust 依赖下载验证**：针对科大源镜像 git:// 协议失效报错问题，配置通过 `sparse+https://mirrors.ustc.edu.cn/crates.io-index/` 稀疏索引重新下载依赖，顺利跑通 Cargo 验证。
4. **前端构建检查**：在 `frontend/apps/web` 下执行 Next.js 生产环境构建命令 `npm run --prefix frontend/apps/web build`，所有 49 个静态与动态渲染页面均通过类型验证和产物生成，显示 `Compiled successfully in 6.0s`。
5. **合入提交**：上述检查全部通过后，将修复的 `lib.rs`、更新的文档和同步的主干代码一同提交完成合并。
