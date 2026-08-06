# PRD：GitHub 原生共创与共享 Cloudflare Pages 小程序市场

## 1. 产品目标

大乘小程序统一为可审计源码、可签名下载、可本地安装、可独立更新与回滚的 MCP Apps。源码与社区协作基于公开 GitHub 组织；AI 的 GitHub 操作使用官方 GitHub MCP/连接器；所有已批准小程序包统一由一个共享 Cloudflare Pages 项目分发。

```text
公开 GitHub 小程序仓库
→ 可信 GitHub Actions 构建与 Release
→ 中央验证和全量静态快照
→ 单一共享 Cloudflare Pages
→ 客户端下载、验证、安装与运行
```

## 2. 产品原则

- 一个小程序一个稳定 plugin ID；默认一个公开 GitHub 仓库对应一个主要小程序。
- 一个版本对应一个不可变内容哈希和一组已签名构件。
- GitHub 交互不得依赖自建 MCP Server；使用官方 GitHub MCP/连接器及 GitHub 原生 Actions/API。
- 多个项目、多个版本的包共同放在一个 Cloudflare Pages 项目，按 plugin ID/version/SHA 隔离。
- 不为每个小程序创建 Pages 项目，不使用 R2。
- 页面按钮和聊天输入调用同一组 MCP Tool；UI 与 runtime 可分离，但属于同一签名 Release。
- 主 App 只提供通用 Host、安装器、沙箱、签名校验和获准能力。
- Pages 只分发静态 catalog、manifest、签名、provenance 和安装包，不承担有状态业务 runtime。

## 3. 共享 Pages 信息架构

```text
/catalog/v1/index.json
/catalog/v1/revocations.json
/apps/<plugin-id>/index.json
/apps/<plugin-id>/latest.json
/apps/<plugin-id>/releases/<version>/<sha256>/manifest.json
/apps/<plugin-id>/releases/<version>/<sha256>/package.zip
/apps/<plugin-id>/releases/<version>/<sha256>/signature.json
/apps/<plugin-id>/releases/<version>/<sha256>/provenance.json
```

`latest.json` 可以变化，但历史版本目录禁止覆盖。发布、撤销或目录变化时，中央工作流重新生成完整静态站点并部署到同一个 Pages 项目。

## 4. 发布者体验

```text
创建或 Fork 公开小程序仓库
→ AI/开发者在分支修改
→ PR 无密钥测试
→ 维护者审核合并
→ 受保护 tag/Release
→ 可信 Actions 构建 Release assets
→ 中央分发工作流验证
→ 共享 Pages 发布
```

普通发布者不需要 Cloudflare API Token，也不创建自己的 Pages 项目。正式版本必须记录 GitHub repository ID、commit、tree hash、许可证、workflow、run、artifact SHA、SBOM 和 provenance。

## 5. 安装体验

```text
市场读取共享 Pages catalog
→ 用户选择小程序和版本
→ 下载匹配平台的不可变包
→ 校验 catalog 签名、SHA-256、大小、plugin ID、version、权限、来源和撤销状态
→ 安全解包到 staging
→ 原子激活
```

用户应看到发布者、源码仓库、许可证、版本、执行位置、权限、下载大小、来源证明、更新和回滚状态。

## 6. GitHub 共创

市场和客户端提供查看源码、报告问题、让 AI 诊断、让 AI 修复、Fork 并自定义、创建 Draft PR、发布派生 App、同步上游和比较差异。

- AI 只能在用户 Fork 或授权分支写入。
- 未经用户确认不得创建公开 Issue/PR。
- Fork PR 无 Secret、只读 Token、无生产 OIDC。
- PR 合并不等于发布。
- 派生 App 必须更换 plugin ID 和签名身份。

## 7. 运行模型

同一市场允许 `local-web`、`desktop-stdio`、`hybrid` 和明确声明的远程 runtime。移动/Web 默认优先本地网页或 WASM；ChatGPT 自动确认可仅支持 desktop native。无论运行位置如何，安装包都从共享 Pages 分发。

## 8. 安全与合规

- 包路径不可变，同版本不同内容发布失败。
- 权限扩大必须重新确认。
- 撤销版本不能新安装或升级。
- 压缩包必须防路径穿越、链接逃逸、设备文件和压缩炸弹。
- Pages 限制在构建前检查；超限时发布失败或采用已签名分片，不得自动回退 R2。
- 公开源码不等于可信，可信度来自受保护仓库、可信 CI、commit 绑定、attestation、签名和审核。

## 9. 首批验收项目

至少选择两个独立公开小程序仓库，其中一个覆盖本地 Web/WASM 或通用 MCP App，另一个可覆盖 desktop native。两者发布多个版本，并同时进入同一个共享 Pages 项目。

## 10. 成功标准

```text
两个以上公开仓库
→ 各自可信 Release
→ 中央验证
→ 单一 Pages 项目同时承载
→ catalog 发现
→ 多平台下载与校验
→ 安装和运行
→ 更新与回滚
→ 撤销生效
```

更新小程序功能时不需要发布新的大乘主 App，也不创建新的插件分发 Pages 项目。
