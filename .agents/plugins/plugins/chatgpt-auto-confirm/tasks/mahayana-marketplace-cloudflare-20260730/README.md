# 大乘 GitHub 原生共创与共享 Cloudflare Pages 小程序市场

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 11`  
状态：已批准实施与真实验收。

## 一句话目标

> 每个小程序由公开 GitHub 仓库承载源码并通过可信 GitHub Actions 发布；所有项目的已批准安装包、版本清单和签名统一放入一个共享 Cloudflare Pages 项目，客户端从该站点安全下载和安装。

## 权威优先级

1. `SHARED_CLOUDFLARE_PAGES_DISTRIBUTION.md`：最终发布与分发架构；
2. `PRD.md`：产品目标；
3. `ACCEPTANCE.md`：完成标准；
4. `PUBLISHING_WORKFLOW.md`：端到端发布流程；
5. `GITHUB_NATIVE_MCP_APP_COLLABORATION.md`：Fork、PR、AI 修复与派生发布；
6. `MULTI_ARTIFACT_MCP_APP.md`、`LOCAL_WEB_MCP_RUNTIME.md`、`LOCAL_FIRST_MCP_APPS.md`、`MCP_APPS_ONLY.md`：安装包、运行时和 Host 约束。

任何旧文档出现“每插件一个 Pages 项目”“插件自己的 Cloudflare 下载站点”“自建 GitHub MCP”“R2 分发”时，均以本任务目标为准并应被迁移或删除。

## 不可变架构决策

- GitHub 操作只使用官方 GitHub MCP/连接器和 GitHub 原生能力，不开发自定义 GitHub MCP Server。
- 默认一个公开源码仓库对应一个主要小程序；正式版本绑定 repository ID、commit、tree hash、许可证、workflow 和 run。
- 每个源码仓库通过可信 Actions 生成不可变 GitHub Release assets、SBOM、provenance 和 attestation。
- 中央发布工作流验证所有资产并生成全量静态站点快照。
- 平台只维护一个小程序分发 Cloudflare Pages 项目；多个项目和多个历史版本共享同一域名，路径按 plugin ID/version/SHA 隔离。
- 禁止每插件创建一个 Pages 项目，禁止 R2，禁止同版本覆盖。
- Pages 只负责静态 catalog 与安装包分发；本地或远程 MCP Runtime 与分发层分离。

## 目标目录

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

## GitHub 共创与供应链

- 用户可以查看源码、报告 Issue、Fork、让 AI 在 Fork 分支修复并创建 Draft PR。
- Fork PR 使用 `pull_request`、只读 Token、无 Secret、无生产 OIDC；不得在特权 `pull_request_target` 中执行 Fork 代码。
- PR 合并不等于发布；正式发布来自受保护上游分支、受保护 tag/Release 和可信工作流。
- 派生 App 必须更换 plugin ID 和发布者身份，并保留上游来源、许可证、权限差异和同步状态。

## 完成条件

至少两个独立公开小程序仓库必须真实发布多个版本，并被同一个 Cloudflare Pages 项目同时托管。客户端必须证明目录发现、下载、签名与哈希校验、安全安装、运行、更新、回滚和撤销；重复版本不同内容必须失败，且不得出现第二个插件分发 Pages 项目或 R2。
