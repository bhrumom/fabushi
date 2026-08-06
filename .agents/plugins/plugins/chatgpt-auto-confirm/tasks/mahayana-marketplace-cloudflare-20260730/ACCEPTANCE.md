# 验收标准：GitHub 原生共创与单一 Cloudflare Pages 多项目分发

任务只有在全部强制项具有真实 GitHub、Actions、Cloudflare Pages 和客户端证据后才能报告 `complete`。

## 1. GitHub 源码与官方 MCP

- [ ] 至少两个独立公开小程序仓库位于公开 GitHub 组织或经批准的公开发布者账户。
- [ ] 每个正式版本绑定 repository ID、owner/name、默认分支、精确 commit、tree hash、SPDX license、workflow 和 run ID。
- [ ] ChatGPT/Codex 的仓库、Issue、分支和 PR 操作使用官方 GitHub MCP/连接器。
- [ ] 仓库中不存在为本任务新建的自定义 GitHub MCP Server、代理协议或重复封装服务。
- [ ] 默认分支、发布标签、CODEOWNERS、ruleset 和必需检查得到真实验证。

## 2. 不受信任 PR 与可信发布隔离

- [ ] Fork PR 使用 `pull_request`、只读 `GITHUB_TOKEN`、无 Secret、无生产 OIDC。
- [ ] 特权 `pull_request_target` 不 checkout、不构建、不执行 Fork 代码或其构件。
- [ ] PR 合并不会直接产生正式市场版本。
- [ ] 正式构件只来自受保护上游 commit、tag/Release 和可信 Actions workflow。
- [ ] SBOM、artifact attestation、provenance 和 source commit 指向同一构建来源。

## 3. 单一共享 Cloudflare Pages 项目

- [ ] 平台只有一个用于小程序包分发的 Cloudflare Pages 项目。
- [ ] 至少两个不同 plugin ID 的包同时存在于该项目同一部署快照中。
- [ ] 两个项目共享同一 Pages 域名，但路径按 `/apps/<plugin-id>/releases/<version>/<sha256>/` 隔离。
- [ ] 不存在每插件一个 Pages 项目的生产实现。
- [ ] 不使用 R2 存放安装包、manifest、签名、provenance 或 catalog。
- [ ] Pages 文件大小与文件数量限制在发布前验证；超限会明确失败或采用已签名分片。

## 4. Catalog 与不可变版本

- [ ] `/catalog/v1/index.json` 能发现至少两个项目及其多个版本。
- [ ] `/catalog/v1/revocations.json` 可表达版本撤销和插件封禁。
- [ ] 每个版本提供 manifest、package、SHA、signature 和 provenance。
- [ ] 同一 `pluginId + version` 不允许对应不同内容。
- [ ] 历史版本路径不可覆盖，`latest.json` 只作为指针。
- [ ] 新增、更新或撤销版本时，中央工作流重新生成并部署完整静态站点快照。

## 5. 发布流水线

- [ ] 每个小程序仓库的可信 Actions 构建、测试、扫描并上传 GitHub Release assets。
- [ ] 中央发布工作流从 GitHub Release 重新下载资产，而不是信任调用方提供的哈希。
- [ ] 中央工作流重新计算 SHA-256 和大小，并验证 plugin ID、version、权限、许可证、签名、provenance 和不可变性。
- [ ] 中央工作流组装所有已批准版本和 catalog 后，只部署一个 Pages 项目。
- [ ] Pages 部署后从公网重新下载包并复核字节。
- [ ] 发布收据记录源码 commit、workflow/run、Release asset、Pages deployment、最终 URL、SHA 和审核结果。

## 6. 安装、更新与回滚

- [ ] 客户端从共享 Pages catalog 发现版本。
- [ ] 客户端从共享 Pages 不可变 URL 下载匹配平台的最小构件。
- [ ] 客户端验证 catalog 签名、SHA-256、大小、plugin ID、version、权限、来源、provenance 和撤销状态。
- [ ] 安装使用随机 staging，防路径穿越、链接逃逸、设备文件和压缩炸弹，并原子激活。
- [ ] 更新失败不破坏当前版本。
- [ ] 回滚恢复完整旧 Release，不混用新旧构件。
- [ ] 撤销版本不能新安装或升级；未撤销历史版本仍可复现下载。

## 7. MCP Apps 与运行时

- [ ] 每个小程序只有一个稳定 plugin ID 和 Tool Contract。
- [ ] MCP Apps 使用 `ui://`、`text/html;profile=mcp-app`、AppBridge、sandbox、CSP 和正确 Tool visibility。
- [ ] 本地 Web/WASM、desktop stdio、hybrid 或远程 runtime 的执行位置明确显示。
- [ ] Pages 仅承担静态分发，不被用作有状态 MCP Runtime。
- [ ] 页面按钮和聊天输入调用同一 Tool Contract。

## 8. 多项目真实证据

- [ ] 项目 A 与项目 B 各自至少发布一个真实版本，至少一个项目发布第二版本。
- [ ] 两个项目在同一 Pages catalog 可搜索和浏览。
- [ ] 两个项目均完成下载、校验、安装和运行。
- [ ] 重复版本不同内容真实发布尝试失败。
- [ ] 撤销测试真实阻止安装。
- [ ] 恶意 Fork PR 无法读取 Secret、写上游、污染缓存或发布正式构件。

## 9. 完成报告

最终报告必须列出：

- 源码仓库、PR、合并 commit、tag/Release 和 Actions runs；
- 官方 GitHub MCP/连接器操作证据；
- 唯一 Pages 项目名称、deployment ID 和共享域名；
- 至少两个 plugin ID 的版本、最终 URL、SHA、大小、签名和 provenance；
- catalog、撤销、下载、安装、运行、更新与回滚证据；
- 无第二个插件分发 Pages 项目、无 R2、无自建 GitHub MCP 的审计结果。

缺少任一强制项时状态必须为 `incomplete`。
