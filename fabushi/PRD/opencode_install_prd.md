# PRD: 解决 opencode.ai 安装脚本失败问题

## 背景
用户尝试执行 `curl -fsSL https://opencode.ai/install | bash` 安装 opencode 时，遇到了 `curl: (56) Failure writing output to destination` 错误。

## 根因分析
通过初步诊断和 `df -h` 指令检查，发现底层原因是磁盘空间耗尽：`/System/Volumes/Data` 的可用空间一度仅剩 `115Mi`，磁盘占用达到 100%。磁盘空间不足导致 `curl` 无法分配存储接收缓存或管道缓冲内存，或者直接导致其调用的后续 `bash` 在解析和执行中抛出异常中断了管道读取进程，最终触发下载失败。

## 需求说明
1. **清理并释放磁盘空间**：扫描并清理无用的缓存数据（如 Flutter 缓存、Xcode Derived Data 等），确保至少有数GB的可用安全空间。
2. **重新执行安装**：磁盘空间释放完成后，再次执行 `curl -fsSL https://opencode.ai/install | bash`，完成 opencode 工具的安装。
3. **测试与完成记录**：验证安装命令 `opencode` 是否可行，撰写遇到的问题与解决流程记录。

## 执行与结果（最终状态）
1. 已临时清理项目级 `build/` 目录缓存，成功找回约 2.8 GB 的空间。
2. 根据用户授权，深度清理了 Xcode 的 `DerivedData` 缓存，将系统可用磁盘空间进一步维护在数 GB 的健康水平。
3. 执行并完成重新安装脚本：`curl -fsSL https://opencode.ai/install | bash` 成功且未发生异常报错。
4. 经验证，`opencode --version` 命令正常输出 `1.3.15` 版本，表明安装工作并配置环境变量 (`.zshrc`) 彻底成功。
